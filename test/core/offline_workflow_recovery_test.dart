import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/core/network/offline_sync_service.dart';
import 'package:lending_nelson/core/security/encryption_service.dart';
import 'package:lending_nelson/core/sync/sync_batch_client.dart';
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

class _RecordingBackend implements SyncBatchClient {
  final submittedEndpoints = <String>[];
  final submittedTransactionUuids = <String>{};

  @override
  Future<Object?> submit(List<Map<String, dynamic>> items) async {
    for (final item in items) {
      submittedEndpoints.add(item['endpoint'] as String);
      submittedTransactionUuids.add(item['transactionUuid'] as String);
    }
    return {
      'syncedTransactionUuids': items
          .map((item) => item['transactionUuid'])
          .toList(),
      'failures': <Map<String, dynamic>>[],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'offline borrower-loan-payment survives restart and syncs once',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lending-offline-workflow-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databasePath = '${directory.path}${Platform.pathSeparator}local.db';
      final encryption = _TestEncryptionService();
      final firstDatabase = DatabaseService(dbPath: databasePath);
      final firstSync = OfflineSyncService(
        databaseService: firstDatabase,
        encryptionService: encryption,
        dio: Dio(),
        connectivity: Connectivity(),
        isForcedOffline: () => true,
      );
      final database = await firstDatabase.database;

      await database.transaction((transaction) async {
        await transaction.insert('borrowers', {
          'id': '00000000-0000-4000-8000-000000000001',
          'first_name': 'encrypted:Synthetic',
          'last_name': 'encrypted:Fixture',
          'national_id': 'encrypted:fixture-id',
          'phone': 'encrypted:fixture-phone',
          'date_of_birth': '1990-01-01',
          'status': 'Active',
          'created_at': '2026-07-28T00:00:00Z',
        });
        await firstSync.enqueue(
          endpoint: '/api/v1/borrowers',
          method: 'POST',
          payload: {'id': '00000000-0000-4000-8000-000000000001'},
          entityType: 'borrower',
          entityLocalId: '00000000-0000-4000-8000-000000000001',
          executor: transaction,
        );
      });
      await database.transaction((transaction) async {
        await transaction.insert('loans', {
          'id': '00000000-0000-4000-8000-000000000002',
          'borrower_id': '00000000-0000-4000-8000-000000000001',
          'request_id': '00000000-0000-4000-8000-000000000012',
          'original_principal': '1000.00',
          'outstanding_principal': '1000.00',
          'monthly_rate': '0.05',
          'term_months': 3,
          'payments_per_month': 1,
          'start_date': '2026-07-28',
          'first_due_date': '2026-08-28',
          'final_due_date': '2026-10-28',
          'created_at': '2026-07-28T00:00:01Z',
        });
        await firstSync.enqueue(
          endpoint: '/api/v1/loans',
          method: 'POST',
          payload: {'requestId': '00000000-0000-4000-8000-000000000012'},
          entityType: 'loan',
          entityLocalId: '00000000-0000-4000-8000-000000000002',
          dependencyIds: ['00000000-0000-4000-8000-000000000001'],
          executor: transaction,
        );
      });
      await database.transaction((transaction) async {
        await transaction.insert('repayments', {
          'id': '00000000-0000-4000-8000-000000000003',
          'loan_id': '00000000-0000-4000-8000-000000000002',
          'request_id': '00000000-0000-4000-8000-000000000013',
          'amount': '100.00',
          'effective_date': '2026-07-28',
          'created_at': '2026-07-28T00:00:02Z',
        });
        await firstSync.enqueue(
          endpoint:
              '/api/v1/loans/00000000-0000-4000-8000-000000000002/payments',
          method: 'POST',
          payload: {
            'requestId': '00000000-0000-4000-8000-000000000013',
            'amount': '100.00',
          },
          entityType: 'repayment',
          entityLocalId: '00000000-0000-4000-8000-000000000003',
          dependencyIds: ['00000000-0000-4000-8000-000000000002'],
          executor: transaction,
        );
      });
      await firstDatabase.close();

      final reopenedDatabase = DatabaseService(dbPath: databasePath);
      addTearDown(reopenedDatabase.close);
      final backend = _RecordingBackend();
      final reopenedSync = OfflineSyncService(
        databaseService: reopenedDatabase,
        encryptionService: encryption,
        dio: Dio(),
        connectivity: Connectivity(),
        isForcedOffline: () => false,
        batchClient: backend,
      );
      final reopened = await reopenedDatabase.database;
      expect(await reopened.query('borrowers'), hasLength(1));
      expect(await reopened.query('loans'), hasLength(1));
      expect(await reopened.query('repayments'), hasLength(1));
      expect(await reopened.query('offline_sync_queue'), hasLength(3));

      await reopenedSync.drainQueue(force: true);

      expect(backend.submittedEndpoints, [
        '/api/v1/borrowers',
        '/api/v1/loans',
        '/api/v1/loans/00000000-0000-4000-8000-000000000002/payments',
      ]);
      expect(backend.submittedTransactionUuids, hasLength(3));
      expect(await reopened.query('borrowers'), hasLength(1));
      expect(await reopened.query('loans'), hasLength(1));
      expect(await reopened.query('repayments'), hasLength(1));
      expect(await reopened.query('offline_sync_queue'), isEmpty);
    },
  );
}
