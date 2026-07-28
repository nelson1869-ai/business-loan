import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/server_health_service.dart';
import '../../borrowers/data/borrower_repository.dart';
import '../../borrowers/data/remote_borrower_repository.dart';
import '../../borrowers/domain/borrower_model.dart';
import '../../loans/data/repositories/local_loan_repository.dart';
import '../../loans/data/repositories/remote_loan_repository.dart';
import '../../loans/data/repositories/remote_payment_repository.dart';
import '../../loans/domain/models/loan.dart';
import '../../loans/domain/models/payment.dart';
import '../domain/dashboard_data.dart';

/// Repository that computes dashboard metrics using local SQLite caching and remote API fallback.
///
/// File: `lib/features/dashboard/data/dashboard_repository.dart`
class DashboardRepository {
  /// Creates the repository with data dependencies and health check service.
  DashboardRepository(
    this._borrowerRepository,
    this._remoteBorrowerRepository,
    this._loanRepository,
    this._localLoanRepository,
    this._paymentRepository,
    this._healthService,
  );

  final BorrowerRepository _borrowerRepository;
  final RemoteBorrowerRepository _remoteBorrowerRepository;
  final RemoteLoanRepository _loanRepository;
  final LocalLoanRepository _localLoanRepository;
  final RemotePaymentRepository _paymentRepository;
  final ServerHealthService _healthService;

  /// Compiles dashboard statistics and lists from online endpoints or local SQLite cache.
  Future<DashboardState> loadDashboard() async {
    // Check server health to resolve actual online/offline status
    final isOnline = await _healthService.isServerReachable();
    unawaited(_refreshPrimaryCaches());

    // 1. Resolve borrowers (remote first if online, fallback to local SQLite)
    List<Borrower> borrowers = const [];
    try {
      if (isOnline) {
        try {
          borrowers = await _remoteBorrowerRepository.getBorrowers();
          await _borrowerRepository.syncRemoteBorrowers(borrowers);
        } catch (_) {
          borrowers = await _borrowerRepository.getBorrowers();
        }
      } else {
        borrowers = await _borrowerRepository.getBorrowers();
      }
    } catch (_) {
      try {
        borrowers = await _borrowerRepository.getBorrowers();
      } catch (_) {
        borrowers = const [];
      }
    }

    final activeBorrowerCount = borrowers
        .where((b) => b.status != 'Deleted')
        .length;

    // 2. Resolve loans (remote first if online, fallback to local SQLite)
    List<Loan> allLoans = const [];
    try {
      if (isOnline) {
        try {
          allLoans = await _loanRepository.getLoans();
          await _localLoanRepository.syncLoans(allLoans);
        } catch (_) {
          allLoans = await _localLoanRepository.getLoans();
        }
      } else {
        allLoans = await _localLoanRepository.getLoans();
      }
    } catch (_) {
      try {
        allLoans = await _localLoanRepository.getLoans();
      } catch (_) {
        allLoans = const [];
      }
    }

    final borrowerIds = borrowers.map((borrower) => borrower.id).toSet();
    final activeLoans = allLoans
        .where(
          (loan) =>
              borrowerIds.isEmpty || borrowerIds.contains(loan.borrowerId),
        )
        .where((loan) => loan.status == 'Active' || loan.status == 'Overdue')
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
      try {
        final borrower = await _borrowerRepository.getBorrower(borrowerId);
        if (borrower != null && borrower.fullName.trim().isNotEmpty) {
          borrowerMap[borrowerId] = borrower.fullName;
          return borrower.fullName;
        }
      } catch (_) {}
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
      // Resolve detailed loan object (installments)
      Loan? detail;
      try {
        if (isOnline) {
          try {
            detail = await _loanRepository.getLoan(loan.id);
            await _localLoanRepository.saveLoan(detail);
          } catch (_) {
            detail = await _localLoanRepository.getLoan(loan.id);
          }
        } else {
          detail = await _localLoanRepository.getLoan(loan.id);
        }
      } catch (_) {
        detail = loan;
      }

      if (detail != null) {
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
      }

      // Resolve recent payment history
      List<LoanPayment> payments = const [];
      try {
        if (isOnline) {
          try {
            payments = await _paymentRepository.history(loan.id);
            await _localLoanRepository.savePayments(loan.id, payments);
          } catch (_) {
            payments = await _localLoanRepository.getPayments(loan.id);
          }
        } else {
          payments = await _localLoanRepository.getPayments(loan.id);
        }
      } catch (_) {
        payments = const [];
      }

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
    }

    try {
      recentActivities.sort(
        (a, b) => b.effectiveDate.compareTo(a.effectiveDate),
      );
      if (recentActivities.length > 15) {
        recentActivities.removeRange(15, recentActivities.length);
      }
    } catch (_) {}

    double totalDisbursed = 0;
    for (final loan in activeLoans) {
      totalDisbursed += double.tryParse(loan.originalPrincipal) ?? 0;
    }

    double monthlyInterestIncomeTotal = 0;
    double sumRate = 0;
    for (final loan in activeLoans) {
      final outstanding = double.tryParse(loan.outstandingPrincipal) ?? 0;
      final rate = double.tryParse(loan.monthlyRate) ?? 0;
      monthlyInterestIncomeTotal += outstanding * rate;
      sumRate += rate;
    }

    final avgRatePct = activeLoans.isNotEmpty
        ? ((sumRate / activeLoans.length) * 100).toStringAsFixed(1)
        : '0.0';

    return DashboardState(
      metrics: DashboardMetrics(
        activeBorrowers: activeBorrowerCount,
        outstandingBalance: totalOutstanding.toStringAsFixed(2),
        collectionDueToday: collectionTodayTotal.toStringAsFixed(2),
        collectionCountToday: collectionTodayCount,
        overdueLoanCount: overdueCount,
        overdueAmount: totalOverdue.toStringAsFixed(2),
        totalActiveLoanCount: activeLoans.length,
        totalPrincipalDisbursed: totalDisbursed.toStringAsFixed(2),
        monthlyInterestIncome: monthlyInterestIncomeTotal.toStringAsFixed(2),
        weightedAverageRate: '$avgRatePct%',
      ),
      recentActivities: recentActivities,
      dueItems: dueItems,
      isLoading: false,
      isOnline: isOnline,
    );
  }

  Future<void> _refreshPrimaryCaches() async {
    try {
      if (!await _healthService.isServerReachable()) return;
      final borrowers = await _remoteBorrowerRepository.getBorrowers();
      await _borrowerRepository.syncRemoteBorrowers(borrowers);
      final loans = await _loanRepository.getLoans();
      await _localLoanRepository.syncLoans(loans);
    } catch (_) {}
  }
}

/// Provider for [DashboardRepository].
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    ref.watch(borrowerRepositoryProvider),
    ref.watch(remoteBorrowerRepositoryProvider),
    ref.watch(remoteLoanRepositoryProvider),
    ref.watch(localLoanRepositoryProvider),
    ref.watch(remotePaymentRepositoryProvider),
    ref.watch(serverHealthServiceProvider),
  );
});
