import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/offline_sync_service.dart';
import '../../loans/data/repositories/remote_loan_repository.dart';
import '../../loans/data/repositories/remote_payment_repository.dart';
import '../../borrowers/data/borrower_repository.dart';
import '../../borrowers/data/remote_borrower_repository.dart';
import '../domain/dashboard_data.dart';

class DashboardRepository {
  DashboardRepository(
    this._borrowerRepository,
    this._remoteBorrowerRepository,
    this._loanRepository,
    this._paymentRepository,
    this._connectivity,
  );

  final BorrowerRepository _borrowerRepository;
  final RemoteBorrowerRepository _remoteBorrowerRepository;
  final RemoteLoanRepository _loanRepository;
  final RemotePaymentRepository _paymentRepository;
  final Connectivity _connectivity;

  Future<DashboardState> loadDashboard() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final isOnline = results.any((r) => r != ConnectivityResult.none);

      final borrowers = isOnline
          ? await _remoteBorrowerRepository.getBorrowers()
          : await _borrowerRepository.getBorrowers();
      final activeBorrowerCount = borrowers
          .where((b) => b.status != 'Deleted')
          .length;

      final allLoans = await _loanRepository.getLoans();
      final activeLoans = allLoans
          .where((l) => l.status == 'Active' || l.status == 'Overdue')
          .toList();

      double totalOutstanding = 0;
      double totalOverdue = 0;
      int overdueCount = 0;

      for (final loan in activeLoans) {
        final outstanding = double.tryParse(loan.outstandingPrincipal) ?? 0;
        totalOutstanding += outstanding;
        if (loan.status == 'Overdue') {
          totalOverdue += outstanding;
          overdueCount++;
        }
      }

      final borrowerMap = <String, String>{
        for (final b in borrowers) b.id: b.fullName,
      };

      Future<String> resolveBorrowerName(String borrowerId) async {
        final name = borrowerMap[borrowerId];
        if (name != null && name.trim().isNotEmpty) return name;
        final borrower = await _borrowerRepository.getBorrower(borrowerId);
        if (borrower != null && borrower.fullName.trim().isNotEmpty) {
          borrowerMap[borrowerId] = borrower.fullName;
          return borrower.fullName;
        }
        final shortId = borrowerId.length >= 8
            ? borrowerId.substring(0, 8)
            : borrowerId;
        return 'Borrower #$shortId';
      }

      final today = DateTime.now();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final dueItems = <DashboardDueItem>[];
      double collectionTodayTotal = 0;
      int collectionTodayCount = 0;

      final recentActivities = <DashboardRecentActivity>[];

      for (final loan in activeLoans.take(10)) {
        try {
          final detail = await _loanRepository.getLoan(loan.id);

          for (final inst in detail.installments) {
            final dueDateStr = inst.dueDate.length >= 10
                ? inst.dueDate.substring(0, 10)
                : inst.dueDate;
            if (dueDateStr == todayStr &&
                (inst.status == 'Scheduled' ||
                    inst.status == 'Overdue' ||
                    inst.status == 'PartiallyPaid')) {
              final expected = double.tryParse(inst.expectedPayment) ?? 0;
              final paid = double.tryParse(inst.paidAmount) ?? 0;
              final due = expected - paid;
              collectionTodayTotal += due;
              collectionTodayCount++;
              final borrowerName = await resolveBorrowerName(loan.borrowerId);
              dueItems.add(
                DashboardDueItem(
                  loanId: loan.id,
                  borrowerId: loan.borrowerId,
                  borrowerName: borrowerName,
                  amountDue: due.toStringAsFixed(2),
                  installmentNumber: inst.installmentNumber,
                  isOverdue: inst.status == 'Overdue',
                ),
              );
            }
          }
        } catch (_) {}

        try {
          final payments = await _paymentRepository.history(loan.id);
          for (final p in payments.take(3)) {
            final borrowerName = await resolveBorrowerName(loan.borrowerId);
            recentActivities.add(
              DashboardRecentActivity(
                loanId: loan.id,
                borrowerId: loan.borrowerId,
                borrowerName: borrowerName,
                amount: p.amount,
                effectiveDate: p.effectiveDate,
                entryType: p.entryType,
              ),
            );
          }
        } catch (_) {}
      }

      recentActivities.sort(
        (a, b) => b.effectiveDate.compareTo(a.effectiveDate),
      );
      if (recentActivities.length > 15) {
        recentActivities.removeRange(15, recentActivities.length);
      }

      return DashboardState(
        metrics: DashboardMetrics(
          activeBorrowers: activeBorrowerCount,
          outstandingBalance: totalOutstanding.toStringAsFixed(2),
          collectionDueToday: collectionTodayTotal.toStringAsFixed(2),
          collectionCountToday: collectionTodayCount,
          overdueLoanCount: overdueCount,
          overdueAmount: totalOverdue.toStringAsFixed(2),
          totalActiveLoanCount: activeLoans.length,
        ),
        recentActivities: recentActivities,
        dueItems: dueItems,
        isLoading: false,
        isOnline: isOnline,
      );
    } catch (error) {
      return DashboardState(error: _friendlyError(error), isLoading: false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('SocketException') ||
        message.contains('Connection refused') ||
        message.contains('Connection timed out')) {
      return 'Could not reach the server. Check your connection.';
    }
    if (message.contains('401')) {
      return 'Session expired. Please log in again.';
    }
    return 'Something went wrong. Pull to retry.';
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    ref.watch(borrowerRepositoryProvider),
    ref.watch(remoteBorrowerRepositoryProvider),
    ref.watch(remoteLoanRepositoryProvider),
    ref.watch(remotePaymentRepositoryProvider),
    ref.watch(connectivityProvider),
  );
});
