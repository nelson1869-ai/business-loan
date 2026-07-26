import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../borrowers/data/borrower_repository.dart';
import '../../data/repositories/local_loan_repository.dart';
import '../../data/repositories/remote_loan_repository.dart';
import '../../domain/models/loan.dart';
import '../../domain/models/overdue_loan_item.dart';
import '../../domain/models/payment.dart';
import '../../data/repositories/remote_payment_repository.dart';
import '../../../dashboard/domain/dashboard_data.dart';
import '../../../../core/network/server_health_service.dart';

/// Loads backend/local loan summaries for one borrower (offline-first).
final borrowerLoansProvider = FutureProvider.autoDispose
    .family<List<Loan>, String>((ref, borrowerId) async {
      final localRepo = ref.watch(localLoanRepositoryProvider);
      final remoteRepo = ref.watch(remoteLoanRepositoryProvider);
      final healthService = ref.watch(serverHealthServiceProvider);

      List<Loan> localLoans = const [];
      try {
        localLoans = await localRepo.getLoans(borrowerId: borrowerId);
      } catch (_) {
        localLoans = const [];
      }

      unawaited(() async {
        try {
          if (!await healthService.isServerReachable()) return;
          final remote = await remoteRepo.getLoans(borrowerId: borrowerId);
          await localRepo.saveLoans(remote);
        } catch (_) {}
      }());

      return localLoans;
    });

/// Loads one loan together with its persisted installment schedule (offline-first).
final loanDetailProvider = FutureProvider.autoDispose.family<Loan, String>((
  ref,
  loanId,
) async {
  final localRepo = ref.watch(localLoanRepositoryProvider);
  final remoteRepo = ref.watch(remoteLoanRepositoryProvider);
  final healthService = ref.watch(serverHealthServiceProvider);

  Loan? localLoan;
  try {
    localLoan = await localRepo.getLoan(loanId);
  } catch (_) {}

  unawaited(() async {
    try {
      if (!await healthService.isServerReachable()) return;
      final remote = await remoteRepo.getLoan(loanId);
      await localRepo.saveLoan(remote);
    } catch (_) {}
  }());

  if (localLoan != null) return localLoan;
  throw StateError('Loan #$loanId not found locally or on server');
});

/// Loads the immutable payment ledger for one loan (offline-first).
final loanPaymentsProvider = FutureProvider.autoDispose
    .family<List<LoanPayment>, String>((ref, loanId) async {
      final localRepo = ref.watch(localLoanRepositoryProvider);
      final remoteRepo = ref.watch(remotePaymentRepositoryProvider);
      final healthService = ref.watch(serverHealthServiceProvider);

      List<LoanPayment> localPayments = const [];
      try {
        localPayments = await localRepo.getPayments(loanId);
      } catch (_) {}

      unawaited(() async {
        try {
          if (!await healthService.isServerReachable()) return;
          final remote = await remoteRepo.history(loanId);
          await localRepo.savePayments(loanId, remote);
        } catch (_) {}
      }());

      return localPayments;
    });

/// All overdue loans with resolved borrower names and computed fields (offline-first).
final overdueLoansProvider = FutureProvider.autoDispose<List<OverdueLoanItem>>((
  ref,
) async {
  final localLoanRepo = ref.watch(localLoanRepositoryProvider);
  final borrowerRepo = ref.watch(borrowerRepositoryProvider);

  List<Loan> loans = const [];
  try {
    loans = await localLoanRepo.getLoans(status: 'Overdue');
  } catch (_) {
    loans = const [];
  }

  final borrowerMap = <String, String>{};
  final results = <OverdueLoanItem>[];

  for (final loan in loans) {
    var borrowerName = borrowerMap[loan.borrowerId];
    if (borrowerName == null) {
      try {
        final borrower = await borrowerRepo.getBorrower(loan.borrowerId);
        if (borrower != null && borrower.fullName.trim().isNotEmpty) {
          borrowerName = borrower.fullName;
        }
      } catch (_) {}
      borrowerName ??=
          'Borrower #${loan.borrowerId.length >= 8 ? loan.borrowerId.substring(0, 8) : loan.borrowerId}';
      borrowerMap[loan.borrowerId] = borrowerName;
    }

    final dueDate = DateTime.tryParse(
      loan.finalDueDate.isNotEmpty ? loan.finalDueDate : loan.firstDueDate,
    );
    final daysOverdue = dueDate != null
        ? DateTime.now().difference(dueDate).inDays
        : 0;

    final outstanding = double.tryParse(loan.outstandingPrincipal) ?? 0;
    final penalty = outstanding * 0.001 * daysOverdue.clamp(0, 365);

    results.add(
      OverdueLoanItem(
        loan: loan,
        borrowerName: borrowerName,
        daysOverdue: daysOverdue.clamp(0, 999),
        penaltyInterest: penalty.toStringAsFixed(2),
      ),
    );
  }

  return results;
});

/// Today's due collection items with progress totals (offline-first).
final todaysCollectionsProvider = FutureProvider.autoDispose<TodaysCollectionData>((
  ref,
) async {
  final localLoanRepo = ref.watch(localLoanRepositoryProvider);
  final borrowerRepo = ref.watch(borrowerRepositoryProvider);

  List<Loan> allLoans = const [];
  try {
    allLoans = await localLoanRepo.getLoans();
  } catch (_) {
    allLoans = const [];
  }

  final activeLoans = allLoans
      .where((l) => l.status == 'Active' || l.status == 'Overdue')
      .toList();

  final today = DateTime.now();
  final todayUtc = today.toUtc();
  final todayStr =
      '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  final todayUtcStr =
      '${todayUtc.year.toString().padLeft(4, '0')}-${todayUtc.month.toString().padLeft(2, '0')}-${todayUtc.day.toString().padLeft(2, '0')}';

  final dueItems = <DashboardDueItem>[];
  double totalDueToday = 0;
  int totalDueCount = 0;
  double totalCollectedToday = 0;

  final borrowerMap = <String, String>{};

  Future<String> resolveName(String borrowerId) async {
    final name = borrowerMap[borrowerId];
    if (name != null) return name;
    try {
      final borrower = await borrowerRepo.getBorrower(borrowerId);
      if (borrower != null && borrower.fullName.trim().isNotEmpty) {
        borrowerMap[borrowerId] = borrower.fullName;
        return borrower.fullName;
      }
    } catch (_) {}
    final shortId = borrowerId.length >= 8
        ? borrowerId.substring(0, 8)
        : borrowerId;
    final fallback = 'Borrower #$shortId';
    borrowerMap[borrowerId] = fallback;
    return fallback;
  }

  for (final loan in activeLoans.take(50)) {
    try {
      Loan? detail;
      try {
        detail = await localLoanRepo.getLoan(loan.id);
      } catch (_) {}
      detail ??= loan;

      for (final inst in detail.installments) {
        final dueDateStr = inst.dueDate.length >= 10
            ? inst.dueDate.substring(0, 10)
            : inst.dueDate;
        if ((dueDateStr == todayStr || dueDateStr == todayUtcStr) &&
            (inst.status == 'Scheduled' ||
                inst.status == 'Overdue' ||
                inst.status == 'PartiallyPaid')) {
          final expected = double.tryParse(inst.expectedPayment) ?? 0;
          final paid = double.tryParse(inst.paidAmount) ?? 0;
          final due = expected - paid;
          if (due > 0) {
            totalDueToday += due;
            totalDueCount++;
            totalCollectedToday += paid;
            final borrowerName = await resolveName(loan.borrowerId);
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
    } catch (_) {}
  }

  return TodaysCollectionData(
    dueItems: dueItems,
    totalDueToday: totalDueToday.toStringAsFixed(2),
    totalCollectedToday: totalCollectedToday.toStringAsFixed(2),
    totalDueCount: totalDueCount,
  );
});

/// All loans with resolved borrower names (offline-first).
final allLoansProvider = FutureProvider.autoDispose<List<LoanWithBorrower>>((
  ref,
) async {
  final localLoanRepo = ref.watch(localLoanRepositoryProvider);
  final remoteLoanRepo = ref.watch(remoteLoanRepositoryProvider);
  final borrowerRepo = ref.watch(borrowerRepositoryProvider);
  final healthService = ref.watch(serverHealthServiceProvider);

  List<Loan> loans = const [];
  try {
    loans = await localLoanRepo.getLoans();
  } catch (_) {}

  unawaited(() async {
    try {
      if (!await healthService.isServerReachable()) return;
      final remote = await remoteLoanRepo.getLoans();
      await localLoanRepo.saveLoans(remote);
    } catch (_) {}
  }());

  final borrowerMap = <String, String>{};
  final results = <LoanWithBorrower>[];

  for (final loan in loans) {
    var name = borrowerMap[loan.borrowerId];
    if (name == null) {
      try {
        final borrower = await borrowerRepo.getBorrower(loan.borrowerId);
        final rawName = borrower?.fullName;
        if (rawName != null && rawName.trim().isNotEmpty) {
          name = rawName;
        }
      } catch (_) {}
      if (name == null) {
        final shortId = loan.id.length >= 8 ? loan.id.substring(0, 8) : loan.id;
        name = 'Loan #$shortId';
      }
      borrowerMap[loan.borrowerId] = name;
    }
    results.add(LoanWithBorrower(loan: loan, borrowerName: name));
  }

  return results;
});

class LoanWithBorrower {
  const LoanWithBorrower({required this.loan, required this.borrowerName});

  final Loan loan;
  final String borrowerName;
}

class TodaysCollectionData {
  const TodaysCollectionData({
    required this.dueItems,
    required this.totalDueToday,
    required this.totalCollectedToday,
    required this.totalDueCount,
  });

  final List<DashboardDueItem> dueItems;
  final String totalDueToday;
  final String totalCollectedToday;
  final int totalDueCount;
}
