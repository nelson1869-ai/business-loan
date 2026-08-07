/// Exact lender-approved terms sent to the backend when creating a loan.
class LoanCreateRequest {
  /// Creates a loan request without performing financial calculations locally.
  const LoanCreateRequest({
    required this.borrowerId,
    required this.requestId,
    required this.originalPrincipal,
    required this.monthlyRate,
    required this.termMonths,
    required this.paymentsPerMonth,
    required this.startDate,
    required this.firstDueDate,
    this.repaymentStructure = 'principal_plus_interest',
  });

  final String borrowerId;
  final String requestId;
  final String originalPrincipal;
  final String monthlyRate;
  final int termMonths;
  final int paymentsPerMonth;
  final String startDate;
  final String firstDueDate;
  final String repaymentStructure;

  /// Converts the approved terms to the backend's camel-case request body.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'borrowerId': borrowerId,
    'requestId': requestId,
    'originalPrincipal': originalPrincipal,
    'monthlyRate': monthlyRate,
    'termMonths': termMonths,
    'paymentsPerMonth': paymentsPerMonth,
    'startDate': startDate,
    'firstDueDate': firstDueDate,
    'repaymentStructure': repaymentStructure,
  };
}
