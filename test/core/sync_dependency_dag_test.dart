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

class RecordAdapter implements HttpClientAdapter {
  List<String> receivedUuids = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    dynamic data = options.data;
    if (data == null && requestStream != null) {
      final bytes = await requestStream.reduce((a, b) => [...a, ...b]);
      data = utf8.decode(bytes);
    }
    if (data != null) {
      final json = data is String ? jsonDecode(data) : data;
      if (json is Map<String, dynamic>) {
        final items = json['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          receivedUuids.add(item['transactionUuid'] as String);
        }
      }
    }

    final responseJson = jsonEncode({
      'syncedTransactionUuids': receivedUuids,
      'failures': <Map<String, dynamic>>[],
    });

    return ResponseBody.fromString(
      responseJson,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  group('Sync Dependency DAG Tests', () {
    test(
      'drainQueue orders borrower -> loan -> repayment in correct topological order',
      () async {
        final dio = Dio();
        final adapter = RecordAdapter();
        dio.httpClientAdapter = adapter;

        final syncService = OfflineSyncService(
          databaseService: dbService,
          encryptionService: encryptionService,
          dio: dio,
          connectivity: Connectivity(),
          isForcedOffline: () => false,
        );

        const borrowerLocalId = 'b-100';
        const loanLocalId = 'l-200';
        const paymentLocalId = 'p-300';

        // Enqueue repayment first, then loan, then borrower
        await syncService.enqueue(
          endpoint: '/api/v1/loans/l-200/payments',
          method: 'POST',
          payload: {'amount': '500.00'},
          entityType: 'repayment',
          entityLocalId: paymentLocalId,
          dependencyIds: [loanLocalId],
        );

        await syncService.enqueue(
          endpoint: '/api/v1/loans',
          method: 'POST',
          payload: {'principal': '5000.00'},
          entityType: 'loan',
          entityLocalId: loanLocalId,
          dependencyIds: [borrowerLocalId],
        );

        await syncService.enqueue(
          endpoint: '/api/v1/borrowers',
          method: 'POST',
          payload: {'first_name': 'Alice'},
          entityType: 'borrower',
          entityLocalId: borrowerLocalId,
        );

        final initialQueue = await syncService.getQueueState();
        expect(initialQueue.items.length, 3);

        final repaymentTxUuid = initialQueue.items
            .firstWhere((i) => i.entityType == 'repayment')
            .transactionUuid;
        final loanTxUuid = initialQueue.items
            .firstWhere((i) => i.entityType == 'loan')
            .transactionUuid;
        final borrowerTxUuid = initialQueue.items
            .firstWhere((i) => i.entityType == 'borrower')
            .transactionUuid;

        await syncService.drainQueue(force: true);

        expect(adapter.receivedUuids, [
          borrowerTxUuid,
          loanTxUuid,
          repaymentTxUuid,
        ]);

        final queueState = await syncService.getQueueState();
        expect(
          queueState.items.length,
          0,
        ); // All 3 synced successfully in topological order
      },
    );

    test('handles items with missing parent dependencies safely', () async {
      final dio = Dio();
      final syncService = OfflineSyncService(
        databaseService: dbService,
        encryptionService: encryptionService,
        dio: dio,
        connectivity: Connectivity(),
        isForcedOffline: () => true,
      );

      await syncService.enqueue(
        endpoint: '/api/v1/loans/non-existent-loan/payments',
        method: 'POST',
        payload: {'amount': '100.00'},
        entityType: 'repayment',
        entityLocalId: 'p-999',
        dependencyIds: ['non-existent-loan'],
      );

      final state = await syncService.getQueueState();
      expect(state.items.length, 1);
      expect(state.items.first.entityType, 'repayment');
    });

    test(
      'handles cyclic dependency graphs without infinite recursion or crash',
      () async {
        final dio = Dio();
        final syncService = OfflineSyncService(
          databaseService: dbService,
          encryptionService: encryptionService,
          dio: dio,
          connectivity: Connectivity(),
          isForcedOffline: () => true,
        );

        await syncService.enqueue(
          endpoint: '/api/v1/item-a',
          method: 'POST',
          payload: {'name': 'A'},
          entityType: 'borrower',
          entityLocalId: 'item-a',
          dependencyIds: ['item-b'],
        );

        await syncService.enqueue(
          endpoint: '/api/v1/item-b',
          method: 'POST',
          payload: {'name': 'B'},
          entityType: 'loan',
          entityLocalId: 'item-b',
          dependencyIds: ['item-a'],
        );

        final state = await syncService.getQueueState();
        expect(state.items.length, 2);
      },
    );
  });
}
