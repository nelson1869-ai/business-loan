import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/borrowers/domain/borrower_model.dart';
import 'package:lending_nelson/features/borrowers/domain/borrower_recommendation.dart';
import 'package:lending_nelson/features/borrowers/domain/borrower_recommendation_service.dart';
import 'package:lending_nelson/features/loans/domain/models/installment.dart';
import 'package:lending_nelson/features/loans/domain/models/loan.dart';

void main() {
  late BorrowerRecommendationService service;
  final refDate = DateTime(2026, 7, 25);

  setUp(() {
    service = const BorrowerRecommendationService();
  });

  group('BorrowerRecommendationService', () {
    test('returns newBorrower recommendation when loan list is empty', () {
      final borrower = Borrower(
        id: 'b1',
        firstName: 'John',
        lastName: 'Doe',
        nationalId: '123456',
        phone: '1234567890',
        dateOfBirth: '1990-01-01',
        status: 'Active',
        createdAt: '2026-01-01',
      );

      final rec = service.evaluate(
        borrower: borrower,
        loans: const [],
        referenceDate: refDate,
      );

      expect(rec.riskTier, RiskTier.newBorrower);
      expect(rec.eligibilityStatus, EligibilityStatus.conditional);
      expect(rec.creditScore, 70);
      expect(rec.maxRecommendedPrincipal, '10000.00');
      expect(rec.suggestedMonthlyRate, '0.03');
    });

    test(
      'returns lowRisk pre-approved recommendation for completed clean loans',
      () {
        final borrower = Borrower(
          id: 'b2',
          firstName: 'Jane',
          lastName: 'Smith',
          nationalId: '654321',
          phone: '0987654321',
          dateOfBirth: '1992-02-02',
          status: 'Active',
          createdAt: '2025-01-01',
        );

        final loans = [
          Loan(
            id: 'l1',
            requestId: 'req1',
            borrowerId: 'b2',
            createdByUserId: 'u1',
            originalPrincipal: '20000.00',
            outstandingPrincipal: '0.00',
            monthlyRate: '0.03',
            termMonths: 6,
            paymentsPerMonth: 1,
            numberOfPayments: 6,
            regularPaymentAmount: '3500.00',
            calculationMethod: 'fixed',
            startDate: '2025-01-01',
            firstDueDate: '2025-02-01',
            finalDueDate: '2025-07-01',
            status: 'Closed',
            createdAt: '2025-01-01',
            installments: [
              Installment(
                id: 'i1',
                loanId: 'l1',
                installmentNumber: 1,
                dueDate: '2025-02-01',
                expectedPayment: '3500.00',
                expectedInterest: '500.00',
                expectedPrincipal: '3000.00',
                expectedRemainingPrincipal: '17000.00',
                paidAmount: '3500.00',
                status: 'Paid',
                createdAt: '2025-01-01',
              ),
            ],
          ),
        ];

        final rec = service.evaluate(
          borrower: borrower,
          loans: loans,
          referenceDate: refDate,
        );

        expect(rec.riskTier, RiskTier.lowRisk);
        expect(rec.eligibilityStatus, EligibilityStatus.approved);
        expect(rec.creditScore, greaterThanOrEqualTo(80));
        expect(rec.suggestedMonthlyRate, '0.025');
      },
    );

    test('returns criticalRisk/declined when borrower profile is blocked', () {
      final borrower = Borrower(
        id: 'b3',
        firstName: 'Bad',
        lastName: 'Borrower',
        nationalId: '999999',
        phone: '0000000000',
        dateOfBirth: '1985-05-05',
        status: 'Blocked',
        createdAt: '2024-01-01',
      );

      final rec = service.evaluate(
        borrower: borrower,
        loans: const [],
        referenceDate: refDate,
      );

      expect(rec.riskTier, RiskTier.criticalRisk);
      expect(rec.eligibilityStatus, EligibilityStatus.declined);
      expect(rec.creditScore, 0);
      expect(rec.maxRecommendedPrincipal, '0.00');
    });
  });
}
