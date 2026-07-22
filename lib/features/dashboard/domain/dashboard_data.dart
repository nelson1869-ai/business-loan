class DashboardMetrics {
  final int activeBorrowers;
  final String outstandingBalance;
  final String collectionDueToday;
  final int collectionCountToday;
  final int overdueLoanCount;
  final String overdueAmount;
  final int totalActiveLoanCount;

  const DashboardMetrics({
    required this.activeBorrowers,
    required this.outstandingBalance,
    required this.collectionDueToday,
    required this.collectionCountToday,
    required this.overdueLoanCount,
    required this.overdueAmount,
    required this.totalActiveLoanCount,
  });
}

class DashboardRecentActivity {
  final String loanId;
  final String borrowerId;
  final String borrowerName;
  final String amount;
  final String effectiveDate;
  final String entryType;

  const DashboardRecentActivity({
    required this.loanId,
    required this.borrowerId,
    required this.borrowerName,
    required this.amount,
    required this.effectiveDate,
    required this.entryType,
  });
}

class DashboardDueItem {
  final String loanId;
  final String borrowerId;
  final String borrowerName;
  final String amountDue;
  final int installmentNumber;
  final bool isOverdue;

  const DashboardDueItem({
    required this.loanId,
    required this.borrowerId,
    required this.borrowerName,
    required this.amountDue,
    required this.installmentNumber,
    required this.isOverdue,
  });
}

class DashboardState {
  final DashboardMetrics? metrics;
  final List<DashboardRecentActivity> recentActivities;
  final List<DashboardDueItem> dueItems;
  final bool isLoading;
  final String? error;
  final bool isOnline;

  const DashboardState({
    this.metrics,
    this.recentActivities = const [],
    this.dueItems = const [],
    this.isLoading = false,
    this.error,
    this.isOnline = true,
  });
}
