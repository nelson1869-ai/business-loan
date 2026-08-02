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

  /// Read-only AI explanation for one persisted loan.
  static String loanExplanation(String loanId) => '$loans/$loanId/explanation';

  /// Offline mutation batch endpoint.
  static const String syncDrain = '/api/v1/sync/drain';

  /// Database-backed financial report projection.
  static const String financialReport = '/api/v1/reports/financial';

  /// Versioned loan-product policy administration.
  static const String loanPolicies = '/api/v1/loan-policies';

  static String activateLoanPolicy(String policyId) =>
      '$loanPolicies/$policyId/activate';

  static String retireLoanPolicy(String policyId) =>
      '$loanPolicies/$policyId/retire';

  /// Online-only maker-checker workflow.
  static const String approvals = '/api/v1/approvals';

  static String approvalDecision(String requestId) =>
      '$approvals/$requestId/decision';

  /// Online-only cash collection reconciliation.
  static const String collectionSessions = '/api/v1/collection-sessions';

  static String collectionSessionAction(String sessionId, String action) =>
      '$collectionSessions/$sessionId/$action';

  /// Immutable, read-only accounting ledger.
  static const String accountingJournals = '/api/v1/accounting/journals';
  static const String accountingTrialBalance =
      '/api/v1/accounting/trial-balance';

  /// Reproducible operational reports.
  static const String portfolioRiskReport = '/api/v1/reports/portfolio-risk';
  static const String collectorReconciliationReport =
      '/api/v1/reports/collector-reconciliation';

  static String borrowerNotes(String borrowerId) =>
      '$borrowers/$borrowerId/notes';

  static String loanNotes(String borrowerId, String loanId) =>
      '$borrowers/$borrowerId/loans/$loanId/notes';

  static String note(String noteId) => '/api/v1/notes/$noteId';

  static const String completedCollectionTasks =
      '/api/v1/collection-tasks/completed';

  static const String collectionTasks = '/api/v1/collection-tasks';

  static String completeScheduledCollectionTask(String taskId) =>
      '$collectionTasks/$taskId/complete';

  static String collectionPromiseStatus(String taskId) =>
      '$collectionTasks/$taskId/promise-status';

  static String completeCollectionTask(String loanId, int installmentNumber) =>
      '/api/v1/collection-tasks/$loanId/$installmentNumber/complete';

  static const String notifications = '/api/v1/notifications';

  static String markNotificationRead(String notificationId) =>
      '$notifications/$notificationId/read';

  static const String markAllNotificationsRead = '$notifications/read-all';

  static String borrowerDocuments(String borrowerId) =>
      '$borrowers/$borrowerId/documents';

  static String loanDocuments(String borrowerId, String loanId) =>
      '$borrowers/$borrowerId/loans/$loanId/documents';

  static String documentContent(String documentId) =>
      '/api/v1/documents/$documentId/content';

  static String document(String documentId) => '/api/v1/documents/$documentId';

  static const String users = '/api/v1/users';

  static String userRole(String userId) => '$users/$userId/role';

  static const String businessSettings = '/api/v1/business-settings';

  /// Admin-only, read-only business assistant.
  static const String adminAssistantChat = '/api/v1/admin-assistant/chat';
  static const String adminAssistantQuestions =
      '/api/v1/admin-assistant/questions';

  /// Health check endpoint for server reachability verification.
  static const String health = '/health';
}
