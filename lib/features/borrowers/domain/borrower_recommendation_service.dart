import 'dart:math';
import '../../loans/domain/models/installment.dart';
import '../../loans/domain/models/loan.dart';
import 'borrower_model.dart';
import 'borrower_recommendation.dart';

/// Pure domain service for calculating credit score & borrower recommendations.
class BorrowerRecommendationService {
  const BorrowerRecommendationService();

  BorrowerRecommendation evaluate({
    required Borrower borrower,
    required List<Loan> loans,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();

    // 1. Profile Status Check
    final statusLower = borrower.status.trim().toLowerCase();
    if (statusLower == 'inactive' ||
        statusLower == 'blocked' ||
        statusLower == 'blacklisted') {
      return BorrowerRecommendation(
        borrowerId: borrower.id,
        creditScore: 0,
        riskTier: RiskTier.criticalRisk,
        eligibilityStatus: EligibilityStatus.declined,
        maxRecommendedPrincipal: '0.00',
        suggestedMonthlyRate: '0.00',
        recommendationReasons: <String>[
          'Borrower account status is "${borrower.status}".',
        ],
        suggestedNextActions: <String>[
          'Refuse new loan applications.',
          'Contact administration to review borrower profile status.',
        ],
      );
    }

    // 2. New Borrower Check (No Loans)
    if (loans.isEmpty) {
      return BorrowerRecommendation(
        borrowerId: borrower.id,
        creditScore: 70,
        riskTier: RiskTier.newBorrower,
        eligibilityStatus: EligibilityStatus.conditional,
        maxRecommendedPrincipal: '10000.00',
        suggestedMonthlyRate: '0.03',
        recommendationReasons: const <String>[
          'No prior loan history on file.',
          'Standard introductory credit limit assigned.',
        ],
        suggestedNextActions: const <String>[
          'Verify national identity document & proof of address.',
          'Confirm borrower income source before disbursement.',
          'Require guarantor signature for principal > 5,000.',
        ],
      );
    }

    // 3. Analyze Loan History & Installments
    int completedLoans = 0;
    int activeLoans = 0;
    int overdueInstallmentsCount = 0;
    double maxHistoricPrincipal = 0.0;

    for (final loan in loans) {
      final loanStatus = loan.status.trim().toLowerCase();
      final principal = double.tryParse(loan.originalPrincipal) ?? 0.0;
      if (principal > maxHistoricPrincipal) {
        maxHistoricPrincipal = principal;
      }

      if (loanStatus == 'closed' ||
          loanStatus == 'paid' ||
          loanStatus == 'completed') {
        completedLoans++;
      } else if (loanStatus == 'active') {
        activeLoans++;
      }

      for (final Installment inst in loan.installments) {
        final instStatus = inst.status.trim().toLowerCase();
        final due = DateTime.tryParse(inst.dueDate);
        final isPastDue = due != null && due.isBefore(now);
        final paid = double.tryParse(inst.paidAmount) ?? 0.0;
        final expected = double.tryParse(inst.expectedPayment) ?? 0.0;

        if (instStatus == 'overdue' || (isPastDue && paid < expected)) {
          overdueInstallmentsCount++;
        }
      }
    }

    // 4. Score Calculation (0 - 100)
    int score = 75;
    // Reward completed loans (+10 per completed loan, max +25)
    score += min(completedLoans * 10, 25);
    // Deduct for active overdue installments (-12 per overdue)
    score -= overdueInstallmentsCount * 12;
    // Deduct slightly for excessive active loans (> 2)
    if (activeLoans > 2) {
      score -= (activeLoans - 2) * 5;
    }

    score = score.clamp(0, 100);

    // 5. Tier & Recommendations Determination
    RiskTier tier;
    EligibilityStatus status;
    String rate;
    double calcMaxPrincipal;
    final reasons = <String>[];
    final actions = <String>[];

    if (overdueInstallmentsCount > 0) {
      reasons.add('$overdueInstallmentsCount overdue installment(s) detected.');
    }
    if (completedLoans > 0) {
      reasons.add('$completedLoans loan(s) successfully fully repaid.');
    }

    if (score >= 85) {
      tier = RiskTier.lowRisk;
      status = EligibilityStatus.approved;
      rate = '0.025'; // 2.5%
      calcMaxPrincipal = max(15000.0, maxHistoricPrincipal * 1.5);
      reasons.add('Excellent track record with strong repayment reliability.');
      actions.add('Pre-approved for instant loan issuance.');
      actions.add('Eligible for preferential interest rate (2.5%/mo).');
    } else if (score >= 65) {
      tier = RiskTier.mediumRisk;
      status = EligibilityStatus.conditional;
      rate = '0.03'; // 3.0%
      calcMaxPrincipal = max(10000.0, maxHistoricPrincipal * 1.1);
      reasons.add('Satisfactory credit history with moderate risk profile.');
      actions.add('Standard loan approval process apply.');
      actions.add('Verify current active employment or business income.');
    } else if (score >= 40) {
      tier = RiskTier.highRisk;
      status = EligibilityStatus.requiresReview;
      rate = '0.04'; // 4.0%
      calcMaxPrincipal = 5000.0;
      reasons.add(
        'Elevated risk profile due to payment delays or multiple active loans.',
      );
      actions.add('Senior credit officer approval required.');
      actions.add('Require co-borrower or tangible collateral.');
    } else {
      tier = RiskTier.criticalRisk;
      status = EligibilityStatus.declined;
      rate = '0.05';
      calcMaxPrincipal = 0.0;
      reasons.add('Poor repayment history and active overdue payments.');
      actions.add(
        'Decline new loan requests until overdue balance is cleared.',
      );
      actions.add('Escalate to collections officer for recovery.');
    }

    final formattedMaxPrincipal = calcMaxPrincipal.toStringAsFixed(2);

    return BorrowerRecommendation(
      borrowerId: borrower.id,
      creditScore: score,
      riskTier: tier,
      eligibilityStatus: status,
      maxRecommendedPrincipal: formattedMaxPrincipal,
      suggestedMonthlyRate: rate,
      recommendationReasons: reasons,
      suggestedNextActions: actions,
    );
  }
}
