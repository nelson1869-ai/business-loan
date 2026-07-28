import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/core/network/offline_sync_service.dart';
import 'package:lending_nelson/core/security/encryption_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class _TestEncryptionService extends EncryptionService {
  _TestEncryptionService() : super(const FlutterSecureStorage());

  @override
  Future<String> encrypt(String plainText) async => 'encrypted:$plainText';

  @override
  Future<String> decrypt(String cipherTextWithIv) async {
    return cipherTextWithIv.replaceFirst('encrypted:', '');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService dbService;
  late EncryptionService encryptionService;
  late OfflineSyncService syncService;

  setUp(() async {
    dbService = DatabaseService(dbPath: inMemoryDatabasePath);
    encryptionService = _TestEncryptionService();
    syncService = OfflineSyncService(
      databaseService: dbService,
      encryptionService: encryptionService,
      dio: Dio(),
      connectivity: Connectivity(),
      isForcedOffline: () => true,
    );
  });

  tearDown(() async {
    await dbService.close();
  });

  group('Sync Lease, Coalescing & Isolation Tests', () {
    test('distinct financial payment operations are NEVER coalesced', () async {
      const loanId = 'loan-101';

      await syncService.enqueue(
        endpoint: '/api/v1/loans/loan-101/payments',
        method: 'POST',
        payload: {'amount': '100.00', 'note': 'First payment'},
        entityType: 'repayment',
        entityLocalId: 'p-1',
        operationType: 'create',
        dependencyIds: [loanId],
      );

      await syncService.enqueue(
        endpoint: '/api/v1/loans/loan-101/payments',
        method: 'POST',
        payload: {'amount': '200.00', 'note': 'Second payment'},
        entityType: 'repayment',
        entityLocalId: 'p-2',
        operationType: 'create',
        dependencyIds: [loanId],
      );

      final state = await syncService.getQueueState();
      expect(state.items.length, 2);
      expect(
        state.items[0].transactionUuid,
        isNot(equals(state.items[1].transactionUuid)),
      );
    });

    test(
      'allowed profile update coalesces payload without changing established transaction UUID',
      () async {
        const borrowerLocalId = 'b-555';

        await syncService.enqueue(
          endpoint: '/api/v1/borrowers/b-555',
          method: 'PUT',
          payload: {'first_name': 'Original Name'},
          entityType: 'borrower',
          entityLocalId: borrowerLocalId,
          operationType: 'update',
        );

        final state1 = await syncService.getQueueState();
        expect(state1.items.length, 1);
        final initialTxUuid = state1.items.first.transactionUuid;

        // Second update to same borrower profile
        await syncService.enqueue(
          endpoint: '/api/v1/borrowers/b-555',
          method: 'PUT',
          payload: {'first_name': 'Updated Name'},
          entityType: 'borrower',
          entityLocalId: borrowerLocalId,
          operationType: 'update',
        );

        final state2 = await syncService.getQueueState();
        expect(state2.items.length, 1);
        expect(state2.items.first.transactionUuid, initialTxUuid);
      },
    );

    test(
      'protects parent queue items from deletion when active items depend on them',
      () async {
        const borrowerLocalId = 'b-777';
        const loanLocalId = 'l-888';

        await syncService.enqueue(
          endpoint: '/api/v1/borrowers',
          method: 'POST',
          payload: {'name': 'Parent Borrower'},
          entityType: 'borrower',
          entityLocalId: borrowerLocalId,
        );

        final borrowerState = await syncService.getQueueState();
        final borrowerTxUuid = borrowerState.items.first.transactionUuid;

        await syncService.enqueue(
          endpoint: '/api/v1/loans',
          method: 'POST',
          payload: {'amount': '1000.00'},
          entityType: 'loan',
          entityLocalId: loanLocalId,
          dependencyIds: [borrowerLocalId],
        );

        // Attempting to delete borrower item without forceCascade must throw DependencyCancellationBlockedException
        expect(
          () async => syncService.deleteItem(borrowerTxUuid),
          throwsA(isA<DependencyCancellationBlockedException>()),
        );

        final stateAfterBlocked = await syncService.getQueueState();
        expect(stateAfterBlocked.items.length, 2);
      },
    );

    test(
      'recovers stale lease records safely during queue initialization',
      () async {
        final db = await dbService.database;
        final staledate = DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 5))
            .toIso8601String();

        await db.insert('offline_sync_queue', {
          'id': 'stale-item-1',
          'transaction_uuid': 'stale-tx-uuid-1',
          'endpoint': '/api/v1/test',
          'method': 'POST',
          'payload_json': '{"encrypted":true}',
          'entity_type': 'borrower',
          'created_at': staledate,
          'status': 'syncing',
          'retry_count': 0,
          'drain_lease_id': 'old-dead-lease-id',
          'lease_acquired_at': staledate,
        });

        final stateBefore = await syncService.getQueueState();
        expect(stateBefore.items.first.status, QueueItemStatus.syncing);

        syncService.start();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final stateAfter = await syncService.getQueueState();
        expect(stateAfter.items.first.status, QueueItemStatus.pending);
        expect(stateAfter.items.first.drainLeaseId, isNull);
      },
    );
  });
}
