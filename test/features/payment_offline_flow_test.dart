import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/core/network/offline_sync_service.dart';
import 'package:lending_nelson/core/security/encryption_service.dart';
import 'package:lending_nelson/features/loans/data/repositories/local_loan_repository.dart';
import 'package:lending_nelson/features/loans/data/repositories/remote_payment_repository.dart';
import 'package:lending_nelson/features/loans/domain/models/payment.dart';
import 'package:lending_nelson/features/loans/presentation/providers/payment_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'supported non-cash payment persists after an authoritative preview',
    () async {
      final databaseService = DatabaseService(dbPath: inMemoryDatabasePath);
      addTearDown(databaseService.close);
      final db = await databaseService.database;
      await db.insert('borrowers', {
        'id': 'borrower-1',
        'first_name': 'Test',
        'last_name': 'Borrower',
        'national_id': 'enc_id',
        'phone': 'enc_phone',
        'date_of_birth': '1990-01-01',
        'status': 'Active',
        'created_at': '2026-01-01T00:00:00Z',
      });
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
        'data_json': jsonEncode({
          'id': 'loan-1',
          'requestId': 'loan-request-1',
          'borrowerId': 'borrower-1',
          'createdByUserId': 'officer-1',
          'originalPrincipal': '1000.00',
          'outstandingPrincipal': '1000.00',
          'monthlyRate': '0.05',
          'termMonths': 12,
          'paymentsPerMonth': 1,
          'numberOfPayments': 12,
          'regularPaymentAmount': '200.00',
          'calculationMethod': 'fixed_periodic_reducing_balance',
          'startDate': '2026-01-01',
          'firstDueDate': '2026-02-01',
          'finalDueDate': '2027-01-01',
          'status': 'Active',
          'createdAt': '2026-01-01T00:00:00Z',
          'installments': [
            {
              'id': 'installment-1',
              'loanId': 'loan-1',
              'installmentNumber': 1,
              'dueDate': '2026-02-01',
              'expectedPayment': '200.00',
              'expectedInterest': '50.00',
              'expectedPrincipal': '150.00',
              'expectedRemainingPrincipal': '850.00',
              'paidAmount': '0.00',
              'status': 'Scheduled',
              'createdAt': '2026-01-01T00:00:00Z',
            },
          ],
        }),
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
          remotePaymentRepositoryProvider.overrideWithValue(
            _PreviewPaymentRepository(),
          ),
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
      );
      await notifier.confirm(
        loanId: 'loan-1',
        amount: '200.00',
        effectiveDate: '2026-07-15',
        method: 'bank',
        deviceId: 'installation-1',
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
    },
  );
}

class _PreviewPaymentRepository extends RemotePaymentRepository {
  _PreviewPaymentRepository() : super(Dio());

  @override
  Future<PaymentPreview> preview({
    required String loanId,
    required String amount,
    required String effectiveDate,
  }) async => PaymentPreview(
    loanId: loanId,
    installmentId: 'installment-1',
    paymentAmount: amount,
    effectiveDate: effectiveDate,
    dueDate: '2026-02-01',
    daysEarly: 0,
    overdueDays: 164,
    accruedInterest: '50.00',
    totalInterestBefore: '50.00',
    principalBefore: '1000.00',
    appliedInterest: '50.00',
    appliedPrincipal: '150.00',
    unappliedCredit: '0.00',
    interestAfter: '0.00',
    principalAfter: '850.00',
    amountAboveScheduled: '0.00',
    nextPeriodInterest: '42.50',
    isPayoff: false,
  );
}

class _TestEncryptionService extends EncryptionService {
  _TestEncryptionService() : super(const FlutterSecureStorage());

  @override
  Future<String> encrypt(String plainText) async => plainText;

  @override
  Future<String> decrypt(String cipherTextWithIv) async => cipherTextWithIv;
}
