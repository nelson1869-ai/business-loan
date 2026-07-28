// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/database_provider.dart';
import '../database/database_service.dart';
import '../security/encryption_service.dart';
import '../sync/sync_batch_client.dart';
import '../sync/sync_dependency_resolver.dart';
import '../sync/sync_lease_manager.dart';
import '../sync/sync_response_validator.dart';
import 'api_client.dart';
import 'server_health_service.dart';
import 'sync_retry_policy.dart';

/// Exception thrown when attempting to delete or cancel a queue item that has active dependencies.
class DependencyCancellationBlockedException implements Exception {
  DependencyCancellationBlockedException(this.message, this.dependentItemIds);
  final String message;
  final List<String> dependentItemIds;

  @override
  String toString() => 'DependencyCancellationBlockedException: $message';
}

/// Typed status values for items in the offline synchronization queue.
enum QueueItemStatus {
  pending,
  syncing,
  retryableFailed,
  permanentlyFailed,
  conflict,
  cancelled,
  blockedByDependency,
}

extension QueueItemStatusX on QueueItemStatus {
  String toDbValue() {
    switch (this) {
      case QueueItemStatus.pending:
        return 'pending';
      case QueueItemStatus.syncing:
        return 'syncing';
      case QueueItemStatus.retryableFailed:
        return 'retryableFailed';
      case QueueItemStatus.permanentlyFailed:
        return 'permanentlyFailed';
      case QueueItemStatus.conflict:
        return 'conflict';
      case QueueItemStatus.cancelled:
        return 'cancelled';
      case QueueItemStatus.blockedByDependency:
        return 'blockedByDependency';
    }
  }

  static QueueItemStatus fromDbValue(String? value) {
    switch (value) {
      case 'syncing':
        return QueueItemStatus.syncing;
      case 'retryableFailed':
        return QueueItemStatus.retryableFailed;
      case 'permanentlyFailed':
        return QueueItemStatus.permanentlyFailed;
      case 'conflict':
        return QueueItemStatus.conflict;
      case 'cancelled':
        return QueueItemStatus.cancelled;
      case 'blockedByDependency':
        return QueueItemStatus.blockedByDependency;
      case 'pending':
      default:
        return QueueItemStatus.pending;
    }
  }
}

/// Typed model representing a failure item returned by the backend sync/drain API.
class SyncFailureDetailsModel {
  const SyncFailureDetailsModel({
    required this.transactionUuid,
    required this.code,
    required this.detail,
    required this.retryable,
  });

  final String transactionUuid;
  final String code;
  final String detail;
  final bool retryable;

  factory SyncFailureDetailsModel.fromJson(Map<String, dynamic> json) {
    return SyncFailureDetailsModel(
      transactionUuid: json['transactionUuid'] as String? ?? '',
      code: json['code'] as String? ?? 'UNKNOWN_ERROR',
      detail: json['detail'] as String? ?? 'Sync failure occurred',
      retryable: json['retryable'] as bool? ?? false,
    );
  }
}

/// Typed model representing the backend response to a batch sync drain request.
class SyncDrainResponseModel {
  const SyncDrainResponseModel({
    required this.syncedTransactionUuids,
    required this.failures,
  });

  final List<String> syncedTransactionUuids;
  final List<SyncFailureDetailsModel> failures;

  factory SyncDrainResponseModel.fromJson(Map<String, dynamic> json) {
    final syncedRaw = json['syncedTransactionUuids'] as List<dynamic>? ?? [];
    final synced = syncedRaw.whereType<String>().toList();

    final failuresRaw = json['failures'] as List<dynamic>? ?? [];
    final failures = failuresRaw
        .whereType<Map<String, dynamic>>()
        .map(SyncFailureDetailsModel.fromJson)
        .toList();

    return SyncDrainResponseModel(
      syncedTransactionUuids: synced,
      failures: failures,
    );
  }
}

/// Typed model representing one item in the offline queue.
class OfflineQueueItemModel {
  const OfflineQueueItemModel({
    required this.id,
    required this.transactionUuid,
    required this.endpoint,
    required this.method,
    required this.payload,
    required this.entityType,
    this.entityLocalId,
    required this.operationType,
    this.dependencyIds = const [],
    required this.createdAt,
    required this.status,
    required this.retryCount,
    this.userId,
    this.lastAttemptAt,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.nextRetryAt,
    this.serverResourceId,
    this.drainLeaseId,
    this.leaseAcquiredAt,
  });

  final String id;
  final String transactionUuid;
  final String endpoint;
  final String method;
  final Map<String, dynamic> payload;
  final String entityType;
  final String? entityLocalId;
  final String operationType;
  final List<String> dependencyIds;
  final DateTime createdAt;
  final QueueItemStatus status;
  final int retryCount;
  final String? userId;
  final DateTime? lastAttemptAt;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final DateTime? nextRetryAt;
  final String? serverResourceId;
  final String? drainLeaseId;
  final DateTime? leaseAcquiredAt;
}

/// Model representing a sync conflict requiring resolution.
class SyncConflictModel {
  const SyncConflictModel({
    required this.id,
    required this.entityType,
    required this.localId,
    this.serverId,
    required this.localData,
    required this.serverData,
    required this.detectedAt,
    required this.status,
  });

  final String id;
  final String entityType;
  final String localId;
  final String? serverId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;
  final DateTime detectedAt;
  final String status;
}

/// State holding queue summary and detailed items.
class OfflineQueueState {
  const OfflineQueueState({
    this.pendingCount = 0,
    this.retryableFailedCount = 0,
    this.permanentlyFailedCount = 0,
    this.conflictCount = 0,
    this.totalCount = 0,
    this.items = const [],
    this.conflicts = const [],
    this.lastSyncedAt,
    this.lastAttemptAt,
    this.lastPartialSyncAt,
    this.lastErrorCode,
    this.isSyncing = false,
    this.processedCount = 0,
    this.processingTotal = 0,
  });

  final int pendingCount;
  final int retryableFailedCount;
  final int permanentlyFailedCount;
  final int conflictCount;
  final int totalCount;
  final List<OfflineQueueItemModel> items;
  final List<SyncConflictModel> conflicts;
  final DateTime? lastSyncedAt;
  final DateTime? lastAttemptAt;
  final DateTime? lastPartialSyncAt;
  final String? lastErrorCode;
  final bool isSyncing;
  final int processedCount;
  final int processingTotal;
}

/// Watches network changes and manages offline mutation replay lifecycle.
class OfflineSyncService {
  OfflineSyncService({
    required DatabaseService databaseService,
    required EncryptionService encryptionService,
    required Dio dio,
    required Connectivity connectivity,
    required bool Function() isForcedOffline,
    ServerHealthService? serverHealthService,
    String? Function()? getCurrentUserId,
    SyncRetryPolicy retryPolicy = const SyncRetryPolicy(),
    SyncDependencyResolver dependencyResolver = const SyncDependencyResolver(),
    SyncResponseValidator responseValidator = const SyncResponseValidator(),
    SyncBatchClient? batchClient,
    SyncLeaseManager leaseManager = const SyncLeaseManager(),
    Random? random,
  }) : _databaseService = databaseService,
       _encryptionService = encryptionService,
       _connectivity = connectivity,
       _isForcedOffline = isForcedOffline,
       _serverHealthService = serverHealthService,
       _getCurrentUserId = getCurrentUserId,
       _retryPolicy = retryPolicy,
       _dependencyResolver = dependencyResolver,
       _responseValidator = responseValidator,
       _batchClient = batchClient ?? DioSyncBatchClient(dio),
       _leaseManager = leaseManager,
       _random = random;

  final DatabaseService _databaseService;
  final EncryptionService _encryptionService;
  final Connectivity _connectivity;
  final bool Function() _isForcedOffline;
  final ServerHealthService? _serverHealthService;
  final String? Function()? _getCurrentUserId;
  final SyncRetryPolicy _retryPolicy;
  final SyncDependencyResolver _dependencyResolver;
  final SyncResponseValidator _responseValidator;
  final SyncBatchClient _batchClient;
  final SyncLeaseManager _leaseManager;
  final Random? _random;
  final Uuid _uuid = const Uuid();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isDraining = false;
  int _processedCount = 0;
  int _processingTotal = 0;
  void Function()? onQueueChanged;

  /// Starts listening for network changes and recovers crash-interrupted records.
  void start() {
    unawaited(_recoverStaleSyncingRecords());
    _subscription ??= _connectivity.onConnectivityChanged.listen((results) {
      if (!_isForcedOffline() && _hasConnection(results)) {
        unawaited(drainQueue());
      }
    });
  }

  /// Recover any items left in 'syncing' status due to an app crash or stale lease (> 2 mins).
  Future<void> _recoverStaleSyncingRecords() async {
    try {
      final database = await _databaseService.database;
      await _leaseManager.recoverStale(database, DateTime.now().toUtc());
      onQueueChanged?.call();
    } catch (_) {}
  }

  /// Stops listening for connectivity changes.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Checks if an operation type and entity type can be safely coalesced.
  bool _canCoalesce(String entityType, String operationType) {
    if (operationType == 'update') {
      if (entityType == 'borrower' ||
          entityType == 'borrower_note' ||
          entityType == 'business_setting') {
        return true;
      }
    }
    return false;
  }

  /// Enqueues a mutation payload encrypted at rest within a caller-supplied transaction or new database connection.
  Future<void> enqueue({
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    String entityType = 'unknown',
    String? entityLocalId,
    String operationType = 'create',
    List<String> dependencyIds = const [],
    String? userId,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _databaseService.database;
    final encodedPayload = jsonEncode(payload);
    final encryptedPayload = await _encryptionService.encrypt(encodedPayload);
    final currentUserId = userId ?? _getCurrentUserId?.call();

    // Check coalescing policy for safe candidates (profile/note/settings updates)
    if (entityLocalId != null && _canCoalesce(entityType, operationType)) {
      final existing = await db.query(
        'offline_sync_queue',
        columns: ['id', 'transaction_uuid'],
        where:
            'entity_type = ? AND entity_local_id = ? AND operation_type = ? '
            "AND status IN ('pending', 'retryableFailed', 'syncing')",
        whereArgs: [entityType, entityLocalId, operationType],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        // Coalesce payload in place without altering established transaction UUID
        await db.update(
          'offline_sync_queue',
          {
            'endpoint': endpoint,
            'method': method,
            'payload_json': encryptedPayload,
            'dependency_ids_json': jsonEncode(dependencyIds),
            'status': QueueItemStatus.pending.toDbValue(),
            'user_id': currentUserId,
            'next_retry_at': null,
            'last_error_code': null,
            'last_error_message': null,
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
        onQueueChanged?.call();
        return;
      }
    }

    final transactionUuid = _uuid.v4();
    await db.insert('offline_sync_queue', {
      'id': _uuid.v4(),
      'transaction_uuid': transactionUuid,
      'endpoint': endpoint,
      'method': method,
      'payload_json': encryptedPayload,
      'entity_type': entityType,
      'entity_local_id': entityLocalId,
      'operation_type': operationType,
      'dependency_ids_json': jsonEncode(dependencyIds),
      'user_id': currentUserId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': QueueItemStatus.pending.toDbValue(),
      'retry_count': 0,
    });

    onQueueChanged?.call();
  }

  /// Replays pending/retryable queued items and removes server-confirmed rows.
  Future<void> drainQueue({bool force = false}) async {
    if (_isDraining || _isForcedOffline()) return;

    final healthService = _serverHealthService;
    if (!force && healthService != null) {
      final reachable = await healthService.isServerReachable();
      if (!reachable) return;
    }

    _isDraining = true;
    final now = DateTime.now().toUtc();
    final currentUserId = _getCurrentUserId?.call();
    String? activeLeaseId;

    try {
      await _recoverStaleSyncingRecords();
      final database = await _databaseService.database;

      // Filter queue by current user scope if authenticated
      final rows = await database.query(
        'offline_sync_queue',
        where: currentUserId != null && currentUserId.isNotEmpty
            ? "status IN ('pending', 'retryableFailed') AND (user_id IS NULL OR user_id = ?)"
            : "status IN ('pending', 'retryableFailed')",
        whereArgs: currentUserId != null && currentUserId.isNotEmpty
            ? [currentUserId]
            : null,
      );
      if (rows.isEmpty) return;

      final eligibleRows = rows.where((row) {
        if (force) return true;
        final nextRetryStr = row['next_retry_at'] as String?;
        if (nextRetryStr != null) {
          final nextRetry = DateTime.tryParse(nextRetryStr);
          if (nextRetry != null && nextRetry.isAfter(now)) {
            return false;
          }
        }
        return true;
      }).toList();

      if (eligibleRows.isEmpty) return;

      final dependencyPlan = _dependencyResolver.resolve(eligibleRows);
      if (dependencyPlan.cyclicRows.isNotEmpty) {
        await database.transaction((txn) async {
          for (final row in dependencyPlan.cyclicRows) {
            await txn.update(
              'offline_sync_queue',
              {
                'status': QueueItemStatus.blockedByDependency.toDbValue(),
                'last_error_code': 'DEPENDENCY_CYCLE',
                'last_error_message': 'Queue dependency cycle requires review',
                'drain_lease_id': null,
                'lease_acquired_at': null,
              },
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        });
      }
      final sortedRows = dependencyPlan.orderedRows;
      if (sortedRows.isEmpty) {
        return;
      }
      _processingTotal = sortedRows.length;
      _processedCount = 0;

      final leaseId = _uuid.v4();
      activeLeaseId = leaseId;
      final transactionUuids = sortedRows
          .map((r) => r['transaction_uuid'] as String)
          .toList();

      await _leaseManager.acquire(
        database: database,
        leaseId: leaseId,
        transactionUuids: transactionUuids,
        now: now,
      );
      onQueueChanged?.call();

      final items = <Map<String, dynamic>>[];
      for (final row in sortedRows) {
        final decryptedPayload = await _encryptionService.decrypt(
          row['payload_json'] as String,
        );
        items.add({
          'transactionUuid': row['transaction_uuid'],
          'endpoint': row['endpoint'],
          'method': row['method'],
          'payload': jsonDecode(decryptedPayload) as Map<String, dynamic>,
          'createdAt': row['created_at'],
        });
      }

      final response = await _batchClient.submit(items);

      final submittedUuidsSet = transactionUuids.toSet();
      final validatedResponse = _responseValidator.validate(
        response: response,
        submittedTransactionUuids: submittedUuidsSet,
      );
      final synced = validatedResponse.syncedTransactionUuids;
      final failures = validatedResponse.failures;
      final omittedUuids = validatedResponse.omittedTransactionUuids;

      bool hasFailures = failures.isNotEmpty || omittedUuids.isNotEmpty;

      await database.transaction((txn) async {
        // Remove server-confirmed items and mark local records as synced
        for (final uuid in synced) {
          if (!submittedUuidsSet.contains(uuid)) continue;

          final row = sortedRows.firstWhere(
            (r) => r['transaction_uuid'] == uuid,
            orElse: () => <String, dynamic>{},
          );
          if (row.isNotEmpty) {
            final entityType = row['entity_type'] as String?;
            final entityLocalId = row['entity_local_id'] as String?;
            if (entityType != null && entityLocalId != null) {
              await _updateLocalEntitySyncStatus(
                txn,
                entityType,
                entityLocalId,
                'synced',
                null,
              );
            }
          }

          await txn.delete(
            'offline_sync_queue',
            where: 'transaction_uuid = ?',
            whereArgs: [uuid],
          );
          _processedCount++;
        }

        // Process explicit failure items
        for (final failure in failures) {
          final uuid = failure.transactionUuid;
          if (!submittedUuidsSet.contains(uuid)) continue;

          final code = failure.code;
          final detail = SyncRetryPolicy.sanitizeErrorMessage(
            failure.detail,
            code,
          );
          final retryable = failure.retryable;

          final existing = sortedRows.firstWhere(
            (r) => r['transaction_uuid'] == uuid,
            orElse: () => <String, dynamic>{},
          );

          final currentRetryCount =
              (existing['retry_count'] as num?)?.toInt() ?? 0;
          final newRetryCount = currentRetryCount + 1;
          final nextRetryAt = _retryPolicy.calculateNextRetryAt(
            lastAttemptAt: now,
            retryCount: newRetryCount,
            customRandom: _random,
          );

          final newStatus = code == 'IDEMPOTENCY_CONFLICT'
              ? QueueItemStatus.conflict
              : (retryable
                    ? QueueItemStatus.retryableFailed
                    : QueueItemStatus.permanentlyFailed);

          await txn.update(
            'offline_sync_queue',
            {
              'status': newStatus.toDbValue(),
              'retry_count': newRetryCount,
              'last_error_code': code,
              'last_error_message': detail,
              'next_retry_at': nextRetryAt.toIso8601String(),
              'drain_lease_id': null,
              'lease_acquired_at': null,
            },
            where: 'transaction_uuid = ?',
            whereArgs: [uuid],
          );
          _processedCount++;

          if (newStatus == QueueItemStatus.conflict) {
            await txn.insert('sync_conflicts', {
              'id': _uuid.v4(),
              'entity_type': existing['entity_type'] ?? 'unknown',
              'local_id': existing['entity_local_id'] ?? uuid,
              'server_id': null,
              'local_data_json': jsonEncode({
                'redacted': true,
                'operation': existing['operation_type'] ?? 'unknown',
              }),
              'server_data_json': jsonEncode({
                'redacted': true,
                'errorCode': code,
              }),
              'detected_at': now.toIso8601String(),
              'status': 'unresolved',
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }

          if (existing.isNotEmpty) {
            final entityType = existing['entity_type'] as String?;
            final entityLocalId = existing['entity_local_id'] as String?;
            if (entityType != null && entityLocalId != null) {
              await _updateLocalEntitySyncStatus(
                txn,
                entityType,
                entityLocalId,
                newStatus == QueueItemStatus.conflict ? 'conflict' : 'failed',
                detail,
              );
            }
          }
        }

        // Handle omitted submitted UUIDs as protocol failures (never leave stuck in syncing)
        for (final uuid in omittedUuids) {
          final existing = sortedRows.firstWhere(
            (r) => r['transaction_uuid'] == uuid,
            orElse: () => <String, dynamic>{},
          );
          final currentRetryCount =
              (existing['retry_count'] as num?)?.toInt() ?? 0;
          final newRetryCount = currentRetryCount + 1;
          final nextRetryAt = _retryPolicy.calculateNextRetryAt(
            lastAttemptAt: now,
            retryCount: newRetryCount,
            customRandom: _random,
          );

          await txn.update(
            'offline_sync_queue',
            {
              'status': QueueItemStatus.retryableFailed.toDbValue(),
              'retry_count': newRetryCount,
              'last_error_code': SanitizedErrorCategory.protocolError,
              'last_error_message':
                  'Submitted item omitted from server response',
              'next_retry_at': nextRetryAt.toIso8601String(),
              'drain_lease_id': null,
              'lease_acquired_at': null,
            },
            where: 'transaction_uuid = ?',
            whereArgs: [uuid],
          );
          _processedCount++;
        }

        // Update metadata based on exact batch outcome
        if (!hasFailures) {
          await txn.insert('sync_metadata', {
            'key': 'last_successful_sync_at',
            'value': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } else if (synced.isNotEmpty) {
          await txn.insert('sync_metadata', {
            'key': 'last_partial_sync_at',
            'value': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } on DioException catch (dioError) {
      final category = SyncRetryPolicy.categorizeError(dioError);
      final sanitizedDetail = SyncRetryPolicy.sanitizeErrorMessage(
        dioError.message,
        category,
      );

      try {
        final database = await _databaseService.database;
        await database.transaction((txn) async {
          final syncingRows = await txn.query(
            'offline_sync_queue',
            where: "status = 'syncing' AND drain_lease_id = ?",
            whereArgs: [activeLeaseId],
          );

          for (final row in syncingRows) {
            final uuid = row['transaction_uuid'] as String;
            final currentRetryCount =
                (row['retry_count'] as num?)?.toInt() ?? 0;
            final newRetryCount = currentRetryCount + 1;
            final nextRetryAt = _retryPolicy.calculateNextRetryAt(
              lastAttemptAt: now,
              retryCount: newRetryCount,
              customRandom: _random,
            );

            await txn.update(
              'offline_sync_queue',
              {
                'status': QueueItemStatus.retryableFailed.toDbValue(),
                'retry_count': newRetryCount,
                'last_error_code': category,
                'last_error_message': sanitizedDetail,
                'next_retry_at': nextRetryAt.toIso8601String(),
                'drain_lease_id': null,
                'lease_acquired_at': null,
              },
              where: 'transaction_uuid = ?',
              whereArgs: [uuid],
            );
          }

          await txn.insert('sync_metadata', {
            'key': 'last_sync_error_code',
            'value': category,
            'updated_at': now.toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        });
      } catch (_) {}
    } catch (e) {
      final category = SanitizedErrorCategory.unknownError;
      final sanitizedDetail = SyncRetryPolicy.sanitizeErrorMessage(
        e.toString(),
        category,
      );

      try {
        final database = await _databaseService.database;
        await database.update(
          'offline_sync_queue',
          {
            'status': QueueItemStatus.retryableFailed.toDbValue(),
            'last_error_code': category,
            'last_error_message': sanitizedDetail,
            'drain_lease_id': null,
            'lease_acquired_at': null,
          },
          where: "status = 'syncing' AND drain_lease_id = ?",
          whereArgs: [activeLeaseId],
        );
      } catch (_) {}
    } finally {
      _isDraining = false;
      onQueueChanged?.call();
    }
  }

  Future<void> _updateLocalEntitySyncStatus(
    dynamic txn,
    String entityType,
    String entityLocalId,
    String syncStatus,
    String? syncError,
  ) async {
    String? tableName;
    switch (entityType) {
      case 'borrower':
        tableName = 'borrowers';
        break;
      case 'loan':
        tableName = 'loans';
        break;
      case 'repayment':
        tableName = 'repayments';
        break;
      case 'guarantor':
        tableName = 'guarantors';
        break;
      case 'borrower_note':
        tableName = 'borrower_notes';
        break;
      case 'document':
        tableName = 'documents';
        break;
    }

    if (tableName != null) {
      try {
        final values = <String, dynamic>{'sync_status': syncStatus};
        if (syncError != null) {
          values['sync_error'] = syncError;
        }
        await txn.update(
          tableName,
          values,
          where: 'id = ?',
          whereArgs: [entityLocalId],
        );
      } catch (_) {}
    }
  }

  /// Returns full queue state with diagnostic items, metadata, and conflicts.
  Future<OfflineQueueState> getQueueState() async {
    final database = await _databaseService.database;
    final currentUserId = _getCurrentUserId?.call();

    final rows = await database.query(
      'offline_sync_queue',
      where: currentUserId != null && currentUserId.isNotEmpty
          ? 'user_id IS NULL OR user_id = ?'
          : null,
      whereArgs: currentUserId != null && currentUserId.isNotEmpty
          ? [currentUserId]
          : null,
      orderBy: 'created_at ASC',
    );

    int pending = 0;
    int retryableFailed = 0;
    int permanentlyFailed = 0;
    int conflict = 0;

    final items = <OfflineQueueItemModel>[];

    for (final row in rows) {
      final statusStr = row['status'] as String? ?? 'pending';
      final status = QueueItemStatusX.fromDbValue(statusStr);

      switch (status) {
        case QueueItemStatus.pending:
        case QueueItemStatus.syncing:
          pending++;
          break;
        case QueueItemStatus.retryableFailed:
        case QueueItemStatus.blockedByDependency:
          retryableFailed++;
          break;
        case QueueItemStatus.permanentlyFailed:
          permanentlyFailed++;
          break;
        case QueueItemStatus.conflict:
          conflict++;
          break;
        case QueueItemStatus.cancelled:
          break;
      }

      final safePayload = <String, dynamic>{
        'operation': '${row['method']} ${row['endpoint']}',
        'entityType': row['entity_type'] ?? 'unknown',
      };

      final depJson = row['dependency_ids_json'] as String?;
      List<String> depIds = const [];
      if (depJson != null && depJson.isNotEmpty) {
        try {
          depIds = (jsonDecode(depJson) as List<dynamic>).cast<String>();
        } catch (_) {}
      }

      items.add(
        OfflineQueueItemModel(
          id: row['id'] as String,
          transactionUuid: row['transaction_uuid'] as String,
          endpoint: row['endpoint'] as String,
          method: row['method'] as String,
          payload: safePayload,
          entityType: row['entity_type'] as String? ?? 'unknown',
          entityLocalId: row['entity_local_id'] as String?,
          operationType: row['operation_type'] as String? ?? 'create',
          dependencyIds: depIds,
          createdAt: DateTime.parse(row['created_at'] as String),
          status: status,
          retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
          userId: row['user_id'] as String?,
          lastAttemptAt: row['last_attempt_at'] != null
              ? DateTime.tryParse(row['last_attempt_at'] as String)
              : null,
          lastErrorCode: row['last_error_code'] as String?,
          lastErrorMessage: row['last_error_message'] as String?,
          nextRetryAt: row['next_retry_at'] != null
              ? DateTime.tryParse(row['next_retry_at'] as String)
              : null,
          serverResourceId: row['server_resource_id'] as String?,
          drainLeaseId: row['drain_lease_id'] as String?,
          leaseAcquiredAt: row['lease_acquired_at'] != null
              ? DateTime.tryParse(row['lease_acquired_at'] as String)
              : null,
        ),
      );
    }

    final conflictRows = await database.query(
      'sync_conflicts',
      orderBy: 'detected_at DESC',
    );
    final conflicts = conflictRows.map((r) {
      return SyncConflictModel(
        id: r['id'] as String,
        entityType: r['entity_type'] as String,
        localId: r['local_id'] as String,
        serverId: r['server_id'] as String?,
        localData:
            jsonDecode(r['local_data_json'] as String) as Map<String, dynamic>,
        serverData:
            jsonDecode(r['server_data_json'] as String) as Map<String, dynamic>,
        detectedAt: DateTime.parse(r['detected_at'] as String),
        status: r['status'] as String,
      );
    }).toList();

    final metaRows = await database.query('sync_metadata');
    DateTime? lastSyncedAt;
    DateTime? lastAttemptAt;
    DateTime? lastPartialSyncAt;
    String? lastErrorCode;

    for (final row in metaRows) {
      final key = row['key'] as String?;
      final value = row['value'] as String?;
      if (key == 'last_successful_sync_at' && value != null) {
        lastSyncedAt = DateTime.tryParse(value);
      } else if (key == 'last_sync_attempt_at' && value != null) {
        lastAttemptAt = DateTime.tryParse(value);
      } else if (key == 'last_partial_sync_at' && value != null) {
        lastPartialSyncAt = DateTime.tryParse(value);
      } else if (key == 'last_sync_error_code') {
        lastErrorCode = value;
      }
    }

    return OfflineQueueState(
      pendingCount: pending,
      retryableFailedCount: retryableFailed,
      permanentlyFailedCount: permanentlyFailed,
      conflictCount: conflict,
      totalCount: rows.length,
      items: items,
      conflicts: conflicts,
      lastSyncedAt: lastSyncedAt,
      lastAttemptAt: lastAttemptAt,
      lastPartialSyncAt: lastPartialSyncAt,
      lastErrorCode: lastErrorCode,
      isSyncing: _isDraining,
      processedCount: _processedCount,
      processingTotal: _processingTotal,
    );
  }

  /// Reset one failed/conflict item back to pending after clearing error states.
  Future<void> retryItem(String transactionUuid) async {
    final database = await _databaseService.database;
    await database.update(
      'offline_sync_queue',
      {
        'status': QueueItemStatus.pending.toDbValue(),
        'next_retry_at': null,
        'drain_lease_id': null,
        'lease_acquired_at': null,
      },
      where: 'transaction_uuid = ?',
      whereArgs: [transactionUuid],
    );
    onQueueChanged?.call();
    unawaited(drainQueue());
  }

  /// Remove one item from the offline sync queue safely if no items depend on it.
  Future<void> deleteItem(
    String transactionUuid, {
    bool forceCascade = false,
  }) async {
    final database = await _databaseService.database;
    final itemRows = await database.query(
      'offline_sync_queue',
      where: 'transaction_uuid = ?',
      whereArgs: [transactionUuid],
      limit: 1,
    );
    if (itemRows.isEmpty) return;

    final item = itemRows.first;
    final id = item['id'] as String;
    final entityLocalId = item['entity_local_id'] as String?;

    if (!forceCascade) {
      final activeRows = await database.query(
        'offline_sync_queue',
        where:
            "status IN ('pending', 'retryableFailed', 'syncing') AND id != ?",
        whereArgs: [id],
      );

      final dependentIds = <String>[];
      for (final row in activeRows) {
        final depJson = row['dependency_ids_json'] as String?;
        if (depJson == null || depJson.isEmpty) continue;
        try {
          final deps = (jsonDecode(depJson) as List<dynamic>).cast<String>();
          if (deps.contains(id) ||
              deps.contains(transactionUuid) ||
              (entityLocalId != null && deps.contains(entityLocalId))) {
            dependentIds.add(row['id'] as String);
          }
        } catch (_) {}
      }

      if (dependentIds.isNotEmpty) {
        throw DependencyCancellationBlockedException(
          'Cannot delete queue item $transactionUuid because active queue items depend on it',
          dependentIds,
        );
      }
    }

    await database.delete(
      'offline_sync_queue',
      where: 'transaction_uuid = ?',
      whereArgs: [transactionUuid],
    );
    onQueueChanged?.call();
  }

  /// Reset all failed items back to pending and drain immediately.
  Future<void> retryAllFailed() async {
    final database = await _databaseService.database;
    await database.update(
      'offline_sync_queue',
      {
        'status': QueueItemStatus.pending.toDbValue(),
        'next_retry_at': null,
        'drain_lease_id': null,
        'lease_acquired_at': null,
      },
      where:
          "status IN ('retryableFailed', 'permanentlyFailed', 'blockedByDependency')",
    );
    onQueueChanged?.call();
    unawaited(drainQueue(force: true));
  }

  /// Removes all failed and cancelled items from the offline sync queue safely.
  Future<void> clearAllFailed() async {
    final database = await _databaseService.database;
    await database.delete(
      'offline_sync_queue',
      where: "status IN ('retryableFailed', 'permanentlyFailed', 'cancelled')",
    );
    onQueueChanged?.call();
  }

  /// Cancels a queued operation without deleting audit history or local business data.
  Future<void> cancelItem(
    String transactionUuid, {
    bool forceCascade = false,
  }) async {
    final database = await _databaseService.database;
    final itemRows = await database.query(
      'offline_sync_queue',
      where: 'transaction_uuid = ?',
      whereArgs: [transactionUuid],
      limit: 1,
    );
    if (itemRows.isEmpty) return;

    final item = itemRows.first;
    final id = item['id'] as String;
    final entityLocalId = item['entity_local_id'] as String?;

    if (!forceCascade) {
      final activeRows = await database.query(
        'offline_sync_queue',
        where:
            "status IN ('pending', 'retryableFailed', 'syncing') AND id != ?",
        whereArgs: [id],
      );

      final dependentIds = <String>[];
      for (final row in activeRows) {
        final depJson = row['dependency_ids_json'] as String?;
        if (depJson == null || depJson.isEmpty) continue;
        try {
          final deps = (jsonDecode(depJson) as List<dynamic>).cast<String>();
          if (deps.contains(id) ||
              deps.contains(transactionUuid) ||
              (entityLocalId != null && deps.contains(entityLocalId))) {
            dependentIds.add(row['id'] as String);
          }
        } catch (_) {}
      }

      if (dependentIds.isNotEmpty) {
        throw DependencyCancellationBlockedException(
          'Cannot cancel queue item $transactionUuid because active queue items depend on it',
          dependentIds,
        );
      }
    }

    await database.update(
      'offline_sync_queue',
      {
        'status': QueueItemStatus.cancelled.toDbValue(),
        'next_retry_at': null,
        'drain_lease_id': null,
        'lease_acquired_at': null,
        'last_error_code': 'CANCELLED_BY_USER',
        'last_error_message': 'Cancelled on this device',
      },
      where: "transaction_uuid = ? AND status != 'syncing'",
      whereArgs: [transactionUuid],
    );
    onQueueChanged?.call();
  }

  /// Resolves a recorded conflict without silently overwriting financial data.
  Future<void> resolveConflict(
    String conflictId, {
    required String strategy,
  }) async {
    const supported = {'serverWins', 'clientWins', 'manual'};
    if (!supported.contains(strategy)) {
      throw ArgumentError.value(strategy, 'strategy');
    }
    final database = await _databaseService.database;
    final rows = await database.query(
      'sync_conflicts',
      where: 'id = ?',
      whereArgs: [conflictId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final entityType = rows.first['entity_type'] as String;
    if (strategy == 'clientWins' &&
        {'loan', 'repayment', 'payment'}.contains(entityType)) {
      throw StateError(
        'Financial conflicts require manual review or server-wins resolution.',
      );
    }
    await database.update(
      'sync_conflicts',
      {'status': strategy == 'manual' ? 'manualReview' : 'resolved:$strategy'},
      where: 'id = ?',
      whereArgs: [conflictId],
    );
    onQueueChanged?.call();
  }

  /// Returns count of pending items.
  Future<int> getPendingCount() async {
    final state = await getQueueState();
    return state.pendingCount;
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}

/// Connectivity instance shared by online checks and queue monitoring.
final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

/// User-controlled test mode that forces all mutations through offline paths.
final forcedOfflineModeProvider = StateProvider<bool>((ref) => false);

/// Long-lived offline synchronization service.
final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final service = OfflineSyncService(
    databaseService: ref.watch(databaseServiceProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    dio: ref.watch(apiClientProvider),
    connectivity: ref.watch(connectivityProvider),
    isForcedOffline: () => ref.read(forcedOfflineModeProvider),
    serverHealthService: ref.watch(serverHealthServiceProvider),
  );
  service.start();
  ref.onDispose(service.dispose);
  return service;
});

/// Reactive StateNotifier providing real-time OfflineQueueState updates.
class OfflineSyncQueueNotifier extends StateNotifier<OfflineQueueState> {
  OfflineSyncQueueNotifier(this._service) : super(const OfflineQueueState()) {
    _service.onQueueChanged = refreshQueueState;
    refreshQueueState();
  }

  final OfflineSyncService _service;

  /// Reload queue state from local SQLite database.
  Future<void> refreshQueueState() async {
    try {
      final newState = await _service.getQueueState();
      if (mounted) {
        state = newState;
      }
    } catch (_) {
      // Keep the last known queue summary when local storage is temporarily unavailable
    }
  }
}

/// Reactive provider for process-wide queue state and counts.
final offlineSyncQueueNotifierProvider =
    StateNotifierProvider<OfflineSyncQueueNotifier, OfflineQueueState>((ref) {
      final service = ref.watch(offlineSyncServiceProvider);
      return OfflineSyncQueueNotifier(service);
    });

/// Reactive provider yielding pending offline count.
final offlineSyncPendingCountProvider = Provider<int>((ref) {
  final queueState = ref.watch(offlineSyncQueueNotifierProvider);
  return queueState.pendingCount;
});

/// StreamProvider watching network connectivity status.
final isOnlineProvider = StreamProvider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});
