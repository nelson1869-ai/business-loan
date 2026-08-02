import 'package:flutter_test/flutter_test.dart';
import 'package:borrower_mobile/features/loans/models/borrower_loan.dart';

void main() {
  group('BorrowerInstallmentSchedule Unit Tests', () {
    test('BorrowerInstallmentItem.fromJson parses correct numbers and fields', () {
      final json = {
        'installmentNumber': 1,
        'dueDate': '2026-09-01T00:00:00.000',
        'expectedPayment': 1020.00,
        'expectedPrincipal': 1000.00,
        'expectedInterest': 20.00,
        'paidAmount': 0.00,
        'remainingBalance': 1020.00,
        'status': 'scheduled',
      };

      final item = BorrowerInstallmentItem.fromJson(json);

      expect(item.installmentNumber, equals(1));
      expect(item.expectedPayment, equals(1020.00));
      expect(item.expectedPrincipal, equals(1000.00));
      expect(item.expectedInterest, equals(20.00));
      expect(item.remainingBalance, equals(1020.00));
      expect(item.status, equals('scheduled'));
    });

    test('BorrowerInstallmentSchedule.fromJson parses collection correctly', () {
      final json = {
        'loanId': 'loan-123',
        'loanReference': 'LN-2026-000123',
        'totalInstallments': 2,
        'paidInstallmentsCount': 1,
        'items': [
          {
            'installmentNumber': 1,
            'dueDate': '2026-08-01T00:00:00.000',
            'expectedPayment': 1020.00,
            'expectedPrincipal': 1000.00,
            'expectedInterest': 20.00,
            'paidAmount': 1020.00,
            'remainingBalance': 0.00,
            'status': 'paid',
          },
          {
            'installmentNumber': 2,
            'dueDate': '2026-09-01T00:00:00.000',
            'expectedPayment': 1020.00,
            'expectedPrincipal': 1000.00,
            'expectedInterest': 20.00,
            'paidAmount': 0.00,
            'remainingBalance': 1020.00,
            'status': 'scheduled',
          },
        ],
      };

      final schedule = BorrowerInstallmentSchedule.fromJson(json);

      expect(schedule.loanId, equals('loan-123'));
      expect(schedule.loanReference, equals('LN-2026-000123'));
      expect(schedule.totalInstallments, equals(2));
      expect(schedule.paidInstallmentsCount, equals(1));
      expect(schedule.items.length, equals(2));
      expect(schedule.items[0].status, equals('paid'));
      expect(schedule.items[1].status, equals('scheduled'));
    });

    test('toJson and fromJson cycle preserves data', () {
      final item = BorrowerInstallmentItem(
        installmentNumber: 1,
        dueDate: DateTime(2026, 9, 1),
        expectedPayment: 500.0,
        expectedPrincipal: 450.0,
        expectedInterest: 50.0,
        paidAmount: 250.0,
        remainingBalance: 250.0,
        status: 'partially_paid',
      );

      final schedule = BorrowerInstallmentSchedule(
        loanId: 'loan-abc',
        loanReference: 'LN-2026-ABCDEF',
        items: [item],
        totalInstallments: 1,
        paidInstallmentsCount: 0,
      );

      final json = schedule.toJson();
      final decoded = BorrowerInstallmentSchedule.fromJson(json);

      expect(decoded.loanId, equals('loan-abc'));
      expect(decoded.items.first.expectedPayment, equals(500.0));
    });
  });
}
