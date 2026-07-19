/// Exact lender-approved terms sent to the backend when creating a loan.
class LoanCreateRequest {
  /// Creates a loan request without performing financial calculations locally.
  const LoanCreateRequest({
    required this.borrowerId,
    required this.originalPrincipal,
    required this.monthlyRate,
    required this.termMonths,
    required this.paymentsPerMonth,
    required this.startDate,
    required this.firstDueDate,
  });

  final String borrowerId;
  final String originalPrincipal;
  final String monthlyRate;
  final int termMonths;
  final int paymentsPerMonth;
  final String startDate;
  final String firstDueDate;

  /// Converts the approved terms to the backend's camel-case request body.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'borrowerId': borrowerId,
    'originalPrincipal': originalPrincipal,
    'monthlyRate': monthlyRate,
    'termMonths': termMonths,
    'paymentsPerMonth': paymentsPerMonth,
    'startDate': startDate,
    'firstDueDate': firstDueDate,
  };
}
