enum RiskTier { lowRisk, mediumRisk, highRisk, criticalRisk, newBorrower }

enum EligibilityStatus { approved, conditional, requiresReview, declined }

extension RiskTierExtension on RiskTier {
  String get label {
    switch (this) {
      case RiskTier.lowRisk:
        return 'Low Risk';
      case RiskTier.mediumRisk:
        return 'Medium Risk';
      case RiskTier.highRisk:
        return 'High Risk';
      case RiskTier.criticalRisk:
        return 'Critical Risk';
      case RiskTier.newBorrower:
        return 'New Borrower';
    }
  }
}

extension EligibilityStatusExtension on EligibilityStatus {
  String get label {
    switch (this) {
      case EligibilityStatus.approved:
        return 'Pre-Approved';
      case EligibilityStatus.conditional:
        return 'Conditional Approval';
      case EligibilityStatus.requiresReview:
        return 'Requires Officer Review';
      case EligibilityStatus.declined:
        return 'Declined / High Risk';
    }
  }
}

class BorrowerRecommendation {
  final String borrowerId;
  final int creditScore; // 0 to 100
  final RiskTier riskTier;
  final EligibilityStatus eligibilityStatus;
  final String maxRecommendedPrincipal;
  final String suggestedMonthlyRate;
  final List<String> recommendationReasons;
  final List<String> suggestedNextActions;

  const BorrowerRecommendation({
    required this.borrowerId,
    required this.creditScore,
    required this.riskTier,
    required this.eligibilityStatus,
    required this.maxRecommendedPrincipal,
    required this.suggestedMonthlyRate,
    required this.recommendationReasons,
    required this.suggestedNextActions,
  });
}
