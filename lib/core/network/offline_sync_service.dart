// ignore_for_file: prefer_initializing_formals

// Dart SDK
import 'dart:async';
import 'dart:convert';

// Third-party packages
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

// Core services
import '../database/database_provider.dart';
import '../database/database_service.dart';
import '../security/encryption_service.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

/// Watches network changes and drains encrypted offline mutations in order.
class OfflineSyncService {
  /// Creates an offline synchronization service.
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

  /// Starts listening for network reconnection events.
  void start() {
    _subscription ??= _connectivity.onConnectivityChanged.listen((results) {
      if (_hasConnection(results)) {
        unawaited(drainQueue());
      }
    });
  }

  /// Stops listening for connectivity changes.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Stores a mutation for later replay with its payload encrypted at rest.
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
    });
  }

  /// Sends queued mutations and removes only server-confirmed rows.
  Future<void> drainQueue() async {
    if (_isDraining) return;
    _isDraining = true;
    try {
      final database = await _databaseService.database;
      final rows = await database.query(
        'offline_sync_queue',
        orderBy: 'created_at ASC',
      );
      if (rows.isEmpty) return;

      final items = <Map<String, dynamic>>[];
      for (final row in rows) {
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
      if (synced.isEmpty) return;

      await database.transaction((transaction) async {
        for (final transactionUuid in synced) {
          await transaction.delete(
            'offline_sync_queue',
            where: 'transaction_uuid = ?',
            whereArgs: [transactionUuid],
          );
        }
      });
    } on DioException {
      // Keep all unconfirmed rows for the next reconnection attempt.
    } finally {
      _isDraining = false;
    }
  }

  /// Returns the count of pending items in the offline queue.
  Future<int> getPendingCount() async {
    final database = await _databaseService.database;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM offline_sync_queue',
    );
    if (result.isEmpty) return 0;
    return (result.first['count'] as num?)?.toInt() ?? 0;
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

/// FutureProvider returning count of pending offline sync items.
final offlineSyncPendingCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(offlineSyncServiceProvider);
  return service.getPendingCount();
});

/// StreamProvider watching network connectivity status.
final isOnlineProvider = StreamProvider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});
