import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/utils/loan_calculator.dart';

void main() {
  group('LoanCalculator Tests', () {
    test('calculatePeriodInterest - standard calculation', () {
      final interest = LoanCalculator.calculatePeriodInterest('1000.00', 0.05);
      expect(interest, '50.00');
    });

    test('calculatePeriodInterest - round half up', () {
      // 123.45 * 0.025 = 3.08625 -> 3.09
      final interest = LoanCalculator.calculatePeriodInterest('123.45', 0.025);
      expect(interest, '3.09');
    });

    test('calculateProratedInterest - half period', () {
      final interest = LoanCalculator.calculateProratedInterest(
        outstandingPrincipal: '1000.00',
        periodicRate: 0.10,
        elapsedDays: 15,
        scheduledPeriodDays: 30,
      );
      expect(interest, '50.00');
    });

    test('allocatePayment - exact interest and principal', () {
      final alloc = LoanCalculator.allocatePayment(
        paymentAmount: '150.00',
        interestDue: '50.00',
        outstandingPrincipal: '100.00',
      );
      expect(alloc.appliedToInterest, '50.00');
      expect(alloc.appliedToPrincipal, '100.00');
      expect(alloc.unappliedCredit, '0.00');
      expect(alloc.remainingInterest, '0.00');
      expect(alloc.remainingPrincipal, '0.00');
    });

    test('allocatePayment - partial payment', () {
      final alloc = LoanCalculator.allocatePayment(
        paymentAmount: '30.00',
        interestDue: '50.00',
        outstandingPrincipal: '500.00',
      );
      expect(alloc.appliedToInterest, '30.00');
      expect(alloc.appliedToPrincipal, '0.00');
      expect(alloc.unappliedCredit, '0.00');
      expect(alloc.remainingInterest, '20.00');
      expect(alloc.remainingPrincipal, '500.00');
    });

    test('allocatePayment - overpayment credit', () {
      final alloc = LoanCalculator.allocatePayment(
        paymentAmount: '600.00',
        interestDue: '50.00',
        outstandingPrincipal: '500.00',
      );
      expect(alloc.appliedToInterest, '50.00');
      expect(alloc.appliedToPrincipal, '500.00');
      expect(alloc.unappliedCredit, '50.00');
      expect(alloc.remainingInterest, '0.00');
      expect(alloc.remainingPrincipal, '0.00');
    });

    test('buildInstallmentSchedule - 12 month loan', () {
      final schedule = LoanCalculator.buildInstallmentSchedule(
        originalPrincipal: '1000.00',
        periodicRate: 0.01, // 1% per period
        numberOfPayments: 12,
      );

      expect(schedule.length, 12);
      expect(schedule.first.number, 1);
      expect(schedule.last.number, 12);
      expect(schedule.last.remainingPrincipal, '0.00');
    });
  });
}
