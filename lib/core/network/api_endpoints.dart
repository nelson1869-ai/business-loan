/// Central API endpoint paths shared by repositories and interceptors.
class ApiEndpoints {
  ApiEndpoints._();

  /// Username/password authentication endpoint.
  static const String token = '/api/v1/auth/token';

  /// Refresh-token exchange endpoint.
  static const String refresh = '/api/v1/auth/refresh';

  /// Borrower collection endpoint.
  static const String borrowers = '/api/v1/borrowers';

  /// Loan collection endpoint.
  static const String loans = '/api/v1/loans';

  /// Non-persistent loan quote calculator endpoint.
  static const String loanQuote = '$loans/quote';

  /// Payment collection for one loan.
  static String loanPayments(String loanId) => '$loans/$loanId/payments';

  /// Offline mutation batch endpoint.
  static const String syncDrain = '/api/v1/sync/drain';

  /// Health check endpoint for server reachability verification.
  static const String health = '/health';
}
