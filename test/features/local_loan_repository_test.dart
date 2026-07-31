import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/features/loans/data/repositories/local_loan_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'hydrates schedule rows when cached loan JSON has no installments',
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
      final cachedLoan = <String, dynamic>{
        'id': 'loan-1',
        'requestId': 'request-1',
        'borrowerId': 'borrower-1',
        'createdByUserId': 'officer-1',
        'originalPrincipal': '1000.00',
        'outstandingPrincipal': '1000.00',
        'monthlyRate': '0.05',
        'termMonths': 1,
        'paymentsPerMonth': 1,
        'numberOfPayments': 1,
        'regularPaymentAmount': '1050.00',
        'calculationMethod': 'fixed_periodic_reducing_balance',
        'startDate': '2026-01-01',
        'firstDueDate': '2026-02-01',
        'finalDueDate': '2026-02-01',
        'status': 'Active',
        'createdAt': '2026-01-01T00:00:00Z',
        'unappliedCredit': '0.00',
        'installments': <dynamic>[],
      };

      await db.insert('loans', {
        'id': 'loan-1',
        'borrower_id': 'borrower-1',
        'request_id': 'request-1',
        'original_principal': '1000.00',
        'outstanding_principal': '1000.00',
        'monthly_rate': '0.05',
        'term_months': 1,
        'payments_per_month': 1,
        'start_date': '2026-01-01',
        'first_due_date': '2026-02-01',
        'final_due_date': '2026-02-01',
        'status': 'Active',
        'data_json': jsonEncode(cachedLoan),
        'created_at': '2026-01-01T00:00:00Z',
        'sync_status': 'synced',
      });
      await db.insert('loan_schedules', {
        'id': 'installment-1',
        'loan_id': 'loan-1',
        'installment_number': 1,
        'due_date': '2026-02-01',
        'expected_payment': '1050.00',
        'interest_amount': '50.00',
        'principal_amount': '1000.00',
        'paid_amount': '0.00',
        'status': 'Scheduled',
        'created_at': '2026-01-01T00:00:00Z',
      });

      final loan = await LocalLoanRepository(databaseService).getLoan('loan-1');

      expect(loan, isNotNull);
      expect(loan!.installments, hasLength(1));
      expect(loan.installments.single.id, 'installment-1');
      expect(loan.installments.single.expectedPayment, '1050.00');
    },
  );
}
