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

  /// Offline mutation batch endpoint.
  static const String syncDrain = '/api/v1/sync/drain';
}
