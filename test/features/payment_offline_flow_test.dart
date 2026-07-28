import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/core/network/offline_sync_service.dart';
import 'package:lending_nelson/core/security/encryption_service.dart';
import 'package:lending_nelson/features/loans/data/repositories/local_loan_repository.dart';
import 'package:lending_nelson/features/loans/presentation/providers/payment_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'offline collection persists payment, balance, and replay queue',
    () async {
      final databaseService = DatabaseService(dbPath: inMemoryDatabasePath);
      addTearDown(databaseService.close);
      final db = await databaseService.database;
      await db.insert('loans', {
        'id': 'loan-1',
        'borrower_id': 'borrower-1',
        'request_id': 'loan-request-1',
        'original_principal': '1000.00',
        'outstanding_principal': '1000.00',
        'monthly_rate': '0.05',
        'term_months': 12,
        'payments_per_month': 1,
        'start_date': '2026-01-01',
        'first_due_date': '2026-02-01',
        'final_due_date': '2027-01-01',
        'status': 'Active',
        'created_at': '2026-01-01T00:00:00Z',
        'sync_status': 'synced',
      });
      await db.insert('loan_schedules', {
        'id': 'installment-1',
        'loan_id': 'loan-1',
        'installment_number': 1,
        'due_date': '2026-02-01',
        'expected_payment': '200.00',
        'interest_amount': '50.00',
        'principal_amount': '150.00',
        'paid_amount': '0.00',
        'status': 'Scheduled',
        'created_at': '2026-01-01T00:00:00Z',
      });

      final localRepository = LocalLoanRepository(databaseService);
      final syncService = OfflineSyncService(
        databaseService: databaseService,
        encryptionService: _TestEncryptionService(),
        dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1')),
        connectivity: Connectivity(),
        isForcedOffline: () => true,
      );
      final container = ProviderContainer(
        overrides: [
          localLoanRepositoryProvider.overrideWithValue(localRepository),
          offlineSyncServiceProvider.overrideWithValue(syncService),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        paymentNotifierProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final notifier = container.read(paymentNotifierProvider.notifier);
      await notifier.loadPreview(
        loanId: 'loan-1',
        amount: '200.00',
        effectiveDate: '2026-07-15',
        outstandingPrincipal: '1000.00',
        interestDue: '50.00',
        dueDate: '2026-02-01',
        daysEarly: 0,
        overdueDays: 164,
        scheduledPayment: '200.00',
        periodicRate: 0.05,
        installmentId: 'installment-1',
      );
      await notifier.confirm(
        loanId: 'loan-1',
        amount: '200.00',
        effectiveDate: '2026-07-15',
        note: 'Offline collection',
      );

      final payments = await db.query('repayments');
      expect(payments, hasLength(1));
      expect(payments.single['sync_status'], 'pending');
      expect(payments.single['amount'], '200.00');

      final loan = (await db.query('loans')).single;
      expect(loan['outstanding_principal'], '850.00');
      expect(loan['sync_status'], 'pending');

      final queue = await db.query('offline_sync_queue');
      expect(queue, hasLength(1));
      expect(queue.single['entity_type'], 'repayment');
      expect(queue.single['status'], 'pending');
    },
  );
}

class _TestEncryptionService extends EncryptionService {
  _TestEncryptionService() : super(const FlutterSecureStorage());

  @override
  Future<String> encrypt(String plainText) async => plainText;

  @override
  Future<String> decrypt(String cipherTextWithIv) async => cipherTextWithIv;
}
