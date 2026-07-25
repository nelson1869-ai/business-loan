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
import 'api_client.dart';
import 'api_endpoints.dart';

/// Typed status values for items in the offline synchronization queue.
enum QueueItemStatus {
  pending,
  syncing,
  retryableFailed,
  permanentlyFailed,
  conflict,
  cancelled,
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
      case 'pending':
      default:
        return QueueItemStatus.pending;
    }
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
    this.lastAttemptAt,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.nextRetryAt,
    this.serverResourceId,
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
  final DateTime? lastAttemptAt;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final DateTime? nextRetryAt;
  final String? serverResourceId;
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
  }) : _databaseService = databaseService,
       _encryptionService = encryptionService,
       _dio = dio,
       _connectivity = connectivity,
       _isForcedOffline = isForcedOffline;

  final DatabaseService _databaseService;
  final EncryptionService _encryptionService;
  final Dio _dio;
  final Connectivity _connectivity;
  final bool Function() _isForcedOffline;
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

  /// Recover any items left in 'syncing' status due to an app crash/restart.
  Future<void> _recoverStaleSyncingRecords() async {
    try {
      final database = await _databaseService.database;
      await database.update(
        'offline_sync_queue',
        {'status': 'pending'},
        where: 'status = ?',
        whereArgs: ['syncing'],
      );
      onQueueChanged?.call();
    } catch (_) {}
  }

  /// Stops listening for connectivity changes.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Enqueues a mutation payload encrypted at rest.
  Future<void> enqueue({
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    String entityType = 'unknown',
    String? entityLocalId,
    String operationType = 'create',
    List<String> dependencyIds = const [],
  }) async {
    final database = await _databaseService.database;
    final encodedPayload = jsonEncode(payload);
    final encryptedPayload = await _encryptionService.encrypt(encodedPayload);
    final transactionUuid = _uuid.v4();

    if (entityLocalId != null) {
      final existing = await database.query(
        'offline_sync_queue',
        columns: ['id'],
        where:
            'entity_type = ? AND entity_local_id = ? AND operation_type = ? '
            "AND status IN ('pending', 'retryableFailed', 'syncing')",
        whereArgs: [entityType, entityLocalId, operationType],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await database.update(
          'offline_sync_queue',
          {
            'endpoint': endpoint,
            'method': method,
            'payload_json': encryptedPayload,
            'dependency_ids_json': jsonEncode(dependencyIds),
            'status': QueueItemStatus.pending.toDbValue(),
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

    await database.insert('offline_sync_queue', {
      'id': _uuid.v4(),
      'transaction_uuid': transactionUuid,
      'endpoint': endpoint,
      'method': method,
      'payload_json': encryptedPayload,
      'entity_type': entityType,
      'entity_local_id': entityLocalId,
      'operation_type': operationType,
      'dependency_ids_json': jsonEncode(dependencyIds),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': QueueItemStatus.pending.toDbValue(),
      'retry_count': 0,
    });

    onQueueChanged?.call();
  }

  /// Sorts rows by entity dependency order (borrower -> loan -> payment, etc.).
  List<Map<String, dynamic>> _sortRowsByDependency(
    List<Map<String, dynamic>> rows,
  ) {
    final entityTypePriority = <String, int>{
      'borrower': 10,
      'guarantor': 20,
      'emergency_contact': 20,
      'borrower_note': 20,
      'loan': 30,
      'loan_schedule': 40,
      'repayment': 50,
      'collection': 50,
      'document': 60,
    };

    final mutableRows = List<Map<String, dynamic>>.from(rows);
    mutableRows.sort((a, b) {
      final typeA = a['entity_type'] as String? ?? 'unknown';
      final typeB = b['entity_type'] as String? ?? 'unknown';
      final priorityA = entityTypePriority[typeA] ?? 99;
      final priorityB = entityTypePriority[typeB] ?? 99;

      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }

      final dateA = a['created_at'] as String? ?? '';
      final dateB = b['created_at'] as String? ?? '';
      return dateA.compareTo(dateB);
    });

    return mutableRows;
  }

  /// Replays pending/retryable queued items and removes server-confirmed rows.
  Future<void> drainQueue() async {
    if (_isDraining || _isForcedOffline()) return;
    _isDraining = true;
    try {
      final database = await _databaseService.database;
      final rows = await database.query(
        'offline_sync_queue',
        where: "status IN ('pending', 'retryableFailed')",
      );
      if (rows.isEmpty) return;

      final now = DateTime.now().toUtc();
      final eligibleRows = rows.where((row) {
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

      final sortedRows = _sortRowsByDependency(eligibleRows);
      _processingTotal = sortedRows.length;
      _processedCount = 0;

      final transactionUuids = sortedRows
          .map((r) => r['transaction_uuid'] as String)
          .toList();

      await database.transaction((txn) async {
        for (final uuid in transactionUuids) {
          await txn.update(
            'offline_sync_queue',
            {
              'status': QueueItemStatus.syncing.toDbValue(),
              'last_attempt_at': now.toIso8601String(),
            },
            where: 'transaction_uuid = ?',
            whereArgs: [uuid],
          );
        }
      });
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

      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.syncDrain,
        data: {'items': items},
      );

      final synced =
          (response.data?['syncedTransactionUuids'] as List<dynamic>?)
              ?.cast<String>() ??
          const <String>[];

      final failures = response.data?['failures'] as List<dynamic>? ?? [];

      await database.transaction((txn) async {
        // Delete server-confirmed items and mark local records as synced
        for (final uuid in synced) {
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

        // Process failure items
        for (final failure in failures) {
          if (failure is Map<String, dynamic>) {
            final uuid = failure['transactionUuid'] as String?;
            if (uuid == null) continue;
            final code = failure['code'] as String? ?? 'UNKNOWN_ERROR';
            final detail =
                failure['detail'] as String? ?? 'Sync failure occurred';
            final retryable = failure['retryable'] as bool? ?? false;

            final existing = sortedRows.firstWhere(
              (r) => r['transaction_uuid'] == uuid,
              orElse: () => <String, dynamic>{},
            );

            final currentRetryCount =
                (existing['retry_count'] as num?)?.toInt() ?? 0;
            final newRetryCount = currentRetryCount + 1;

            final nextRetryDelaySec = min(
              300,
              pow(2, newRetryCount).toInt() * 5,
            );
            final nextRetryAt = now.add(Duration(seconds: nextRetryDelaySec));

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
        }

        // Store last successful sync metadata
        await txn.insert('sync_metadata', {
          'key': 'last_synced_at',
          'value': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    } on DioException catch (dioError) {
      try {
        final database = await _databaseService.database;
        await database.update('offline_sync_queue', {
          'status': QueueItemStatus.retryableFailed.toDbValue(),
          'last_error_code': dioError.type.name,
          'last_error_message': 'Network error during sync replay',
        }, where: "status = 'syncing'");
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

  /// Returns full queue state with diagnostic items and conflicts.
  Future<OfflineQueueState> getQueueState() async {
    final database = await _databaseService.database;
    final rows = await database.query(
      'offline_sync_queue',
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
          lastAttemptAt: row['last_attempt_at'] != null
              ? DateTime.tryParse(row['last_attempt_at'] as String)
              : null,
          lastErrorCode: row['last_error_code'] as String?,
          lastErrorMessage: row['last_error_message'] as String?,
          nextRetryAt: row['next_retry_at'] != null
              ? DateTime.tryParse(row['next_retry_at'] as String)
              : null,
          serverResourceId: row['server_resource_id'] as String?,
        ),
      );
    }

    // Load conflicts
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

    // Load last sync metadata
    final metaRows = await database.query(
      'sync_metadata',
      where: "key = 'last_synced_at'",
      limit: 1,
    );
    DateTime? lastSyncedAt;
    if (metaRows.isNotEmpty) {
      lastSyncedAt = DateTime.tryParse(metaRows.first['value'] as String);
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
      isSyncing: _isDraining,
      processedCount: _processedCount,
      processingTotal: _processingTotal,
    );
  }

  /// Reset one failed/conflict item back to pending.
  Future<void> retryItem(String transactionUuid) async {
    final database = await _databaseService.database;
    await database.update(
      'offline_sync_queue',
      {'status': QueueItemStatus.pending.toDbValue(), 'next_retry_at': null},
      where: 'transaction_uuid = ?',
      whereArgs: [transactionUuid],
    );
    onQueueChanged?.call();
    unawaited(drainQueue());
  }

  /// Remove one item from the offline sync queue.
  Future<void> deleteItem(String transactionUuid) async {
    final database = await _databaseService.database;
    await database.delete(
      'offline_sync_queue',
      where: 'transaction_uuid = ?',
      whereArgs: [transactionUuid],
    );
    onQueueChanged?.call();
  }

  /// Cancels a queued operation without deleting its audit trail.
  Future<void> cancelItem(String transactionUuid) async {
    final database = await _databaseService.database;
    await database.update(
      'offline_sync_queue',
      {
        'status': QueueItemStatus.cancelled.toDbValue(),
        'next_retry_at': null,
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
      // Keep the last known queue summary when local storage is temporarily
      // unavailable. Queue mutations still report their own actionable errors.
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
