import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/loans/domain/models/loan.dart';

void main() {
  test('loan detail preserves exact decimals and parses installments', () {
    final json = _loanJson();

    final loan = Loan.fromJson(json);

    expect(loan.originalPrincipal, '1000.00');
    expect(loan.monthlyRate, '0.10000000');
    expect(loan.numberOfPayments, 10);
    expect(loan.installments, hasLength(1));
    expect(loan.installments.single.expectedInterest, '50.00');
    expect(loan.toJson(), json);
  });

  test('loan-list response may omit installments', () {
    final json = _loanJson()..remove('installments');

    final loan = Loan.fromJson(json);

    expect(loan.installments, isEmpty);
  });

  test('installment collection cannot be modified', () {
    final loan = Loan.fromJson(_loanJson());

    expect(() => loan.installments.clear(), throwsUnsupportedError);
  });

  test('binary floating-point financial values are rejected', () {
    final json = _loanJson()..['monthlyRate'] = 0.1;

    expect(() => Loan.fromJson(json), throwsFormatException);
  });
}

Map<String, dynamic> _loanJson() => <String, dynamic>{
  'id': '00000000-0000-4000-8000-000000000010',
  'requestId': '00000000-0000-4000-8000-000000000002',
  'borrowerId': '00000000-0000-4000-8000-000000000001',
  'createdByUserId': '00000000-0000-4000-8000-000000000099',
  'originalPrincipal': '1000.00',
  'outstandingPrincipal': '1000.00',
  'monthlyRate': '0.10000000',
  'termMonths': 5,
  'paymentsPerMonth': 2,
  'numberOfPayments': 10,
  'regularPaymentAmount': '129.50',
  'calculationMethod': 'fixed_periodic_reducing_balance',
  'startDate': '2026-08-01',
  'firstDueDate': '2026-08-05',
  'finalDueDate': '2026-12-20',
  'status': 'Active',
  'createdAt': '2026-08-01T00:00:00Z',
  'unappliedCredit': '0.00',
  'installments': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': '00000000-0000-4000-8000-000000000011',
      'loanId': '00000000-0000-4000-8000-000000000010',
      'installmentNumber': 1,
      'dueDate': '2026-08-05',
      'expectedPayment': '129.50',
      'expectedInterest': '50.00',
      'expectedPrincipal': '79.50',
      'expectedRemainingPrincipal': '920.50',
      'paidAmount': '0.00',
      'status': 'Scheduled',
      'createdAt': '2026-08-01T00:00:00Z',
    },
  ],
};
