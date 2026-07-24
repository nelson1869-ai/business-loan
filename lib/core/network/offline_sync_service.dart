// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final DateTime createdAt;
  final QueueItemStatus status;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final DateTime? nextRetryAt;
  final String? serverResourceId;
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
  });

  final int pendingCount;
  final int retryableFailedCount;
  final int permanentlyFailedCount;
  final int conflictCount;
  final int totalCount;
  final List<OfflineQueueItemModel> items;
}

/// Watches network changes and manages offline mutation replay lifecycle.
class OfflineSyncService {
  OfflineSyncService({
    required DatabaseService databaseService,
    required EncryptionService encryptionService,
    required Dio dio,
    required Connectivity connectivity,
  }) : _databaseService = databaseService,
       _encryptionService = encryptionService,
       _dio = dio,
       _connectivity = connectivity;

  final DatabaseService _databaseService;
  final EncryptionService _encryptionService;
  final Dio _dio;
  final Connectivity _connectivity;
  final Uuid _uuid = const Uuid();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isDraining = false;
  void Function()? onQueueChanged;

  /// Starts listening for network changes and recovers crash-interrupted records.
  void start() {
    unawaited(_recoverStaleSyncingRecords());
    _subscription ??= _connectivity.onConnectivityChanged.listen((results) {
      if (_hasConnection(results)) {
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
  }) async {
    final database = await _databaseService.database;
    final encodedPayload = jsonEncode(payload);
    final encryptedPayload = await _encryptionService.encrypt(encodedPayload);
    final transactionUuid = _uuid.v4();

    await database.insert('offline_sync_queue', {
      'id': _uuid.v4(),
      'transaction_uuid': transactionUuid,
      'endpoint': endpoint,
      'method': method,
      'payload_json': encryptedPayload,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': QueueItemStatus.pending.toDbValue(),
      'retry_count': 0,
    });

    onQueueChanged?.call();
  }

  /// Replays pending/retryable queued items and removes server-confirmed rows.
  Future<void> drainQueue() async {
    if (_isDraining) return;
    _isDraining = true;
    try {
      final database = await _databaseService.database;
      final rows = await database.query(
        'offline_sync_queue',
        where: "status IN ('pending', 'retryableFailed')",
        orderBy: 'created_at ASC',
      );
      if (rows.isEmpty) return;

      // Filter out items whose exponential backoff wait hasn't elapsed
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

      // Mark items as 'syncing' before sending
      final transactionUuids = eligibleRows
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
      for (final row in eligibleRows) {
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
        // Delete server-confirmed items
        for (final uuid in synced) {
          await txn.delete(
            'offline_sync_queue',
            where: 'transaction_uuid = ?',
            whereArgs: [uuid],
          );
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

            final existing = eligibleRows.firstWhere(
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
          }
        }
      });
    } on DioException catch (dioError) {
      // Revert remaining syncing items back to retryableFailed
      try {
        final database = await _databaseService.database;
        await database.update(
          'offline_sync_queue',
          {
            'status': QueueItemStatus.retryableFailed.toDbValue(),
            'last_error_code': dioError.type.name,
            'last_error_message': 'Network error during sync replay',
          },
          where: 'status = ?',
          whereArgs: ['syncing'],
        );
      } catch (_) {}
    } finally {
      _isDraining = false;
      onQueueChanged?.call();
    }
  }

  /// Returns full queue status with diagnostic items.
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
      }

      // Safe placeholder for UI (full payload remains encrypted at rest)
      final safePayload = <String, dynamic>{
        'operation': '${row['method']} ${row['endpoint']}',
        'redacted': true,
      };

      items.add(
        OfflineQueueItemModel(
          id: row['id'] as String,
          transactionUuid: row['transaction_uuid'] as String,
          endpoint: row['endpoint'] as String,
          method: row['method'] as String,
          payload: safePayload,
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

    return OfflineQueueState(
      pendingCount: pending,
      retryableFailedCount: retryableFailed,
      permanentlyFailedCount: permanentlyFailed,
      conflictCount: conflict,
      totalCount: rows.length,
      items: items,
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

/// Long-lived offline synchronization service.
final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final service = OfflineSyncService(
    databaseService: ref.watch(databaseServiceProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    dio: ref.watch(apiClientProvider),
    connectivity: ref.watch(connectivityProvider),
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
    final newState = await _service.getQueueState();
    if (mounted) {
      state = newState;
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
