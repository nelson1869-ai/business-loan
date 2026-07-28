import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/core/network/offline_sync_service.dart';
import 'package:lending_nelson/core/security/encryption_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestEncryptionService extends EncryptionService {
  _TestEncryptionService() : super(const FlutterSecureStorage());

  @override
  Future<String> encrypt(String plainText) async => 'encrypted:$plainText';

  @override
  Future<String> decrypt(String cipherTextWithIv) async {
    return cipherTextWithIv.replaceFirst('encrypted:', '');
  }
}

class MockAdapter implements HttpClientAdapter {
  Map<String, dynamic> responsePayload = {};
  int statusCode = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final payloadJson = responsePayload.isNotEmpty
        ? _jsonEncode(responsePayload)
        : '{"syncedTransactionUuids":[],"failures":[]}';
    return ResponseBody.fromString(
      payloadJson,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  String _jsonEncode(dynamic object) {
    return jsonEncode(object);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService dbService;
  late EncryptionService encryptionService;

  setUp(() async {
    dbService = DatabaseService(dbPath: inMemoryDatabasePath);
    encryptionService = _TestEncryptionService();
  });

  tearDown(() async {
    await dbService.close();
  });

  group('Sync Response Validation Tests', () {
    test('SyncDrainResponseModel parses valid response cleanly', () {
      final json = {
        'syncedTransactionUuids': ['tx-1', 'tx-2'],
        'failures': [
          {
            'transactionUuid': 'tx-3',
            'code': 'IDEMPOTENCY_CONFLICT',
            'detail': 'Conflict occurred',
            'retryable': false,
          },
        ],
      };

      final response = SyncDrainResponseModel.fromJson(json);
      expect(response.syncedTransactionUuids, ['tx-1', 'tx-2']);
      expect(response.failures.length, 1);
      expect(response.failures.first.transactionUuid, 'tx-3');
      expect(response.failures.first.code, 'IDEMPOTENCY_CONFLICT');
      expect(response.failures.first.retryable, false);
    });

    test('SyncDrainResponseModel handles empty and malformed json safely', () {
      final response = SyncDrainResponseModel.fromJson({});
      expect(response.syncedTransactionUuids, isEmpty);
      expect(response.failures, isEmpty);

      final malformedFailure = SyncDrainResponseModel.fromJson({
        'syncedTransactionUuids': null,
        'failures': [
          {'transactionUuid': null, 'code': null},
          'invalid_string_item',
        ],
      });
      expect(malformedFailure.syncedTransactionUuids, isEmpty);
      expect(malformedFailure.failures.length, 1);
      expect(malformedFailure.failures.first.code, 'UNKNOWN_ERROR');
    });

    test(
      'omitted submitted UUIDs are marked as retryable protocol failures',
      () async {
        final dio = Dio();
        final adapter = MockAdapter();
        dio.httpClientAdapter = adapter;

        final syncService = OfflineSyncService(
          databaseService: dbService,
          encryptionService: encryptionService,
          dio: dio,
          connectivity: Connectivity(),
          isForcedOffline: () => false,
        );

        await syncService.enqueue(
          endpoint: '/api/v1/borrowers',
          method: 'POST',
          payload: {'name': 'Bob'},
          entityType: 'borrower',
        );

        final stateBefore = await syncService.getQueueState();
        expect(stateBefore.items.length, 1);
        final txUuid = stateBefore.items.first.transactionUuid;

        // Server returns empty response (omitting txUuid)
        adapter.responsePayload = {
          'syncedTransactionUuids': <String>[],
          'failures': <Map<String, dynamic>>[],
        };

        await syncService.drainQueue(force: true);

        final stateAfter = await syncService.getQueueState();
        expect(stateAfter.items.length, 1);
        final itemAfter = stateAfter.items.first;
        expect(itemAfter.transactionUuid, txUuid);
        expect(itemAfter.status, QueueItemStatus.retryableFailed);
        expect(itemAfter.lastErrorCode, 'PROTOCOL_ERROR');
        expect(itemAfter.retryCount, 1);
      },
    );
  });
}
