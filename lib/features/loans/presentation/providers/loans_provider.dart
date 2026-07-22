import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../borrowers/data/borrower_repository.dart';
import '../../data/repositories/remote_loan_repository.dart';
import '../../domain/models/loan.dart';
import '../../domain/models/overdue_loan_item.dart';
import '../../domain/models/payment.dart';
import '../../data/repositories/remote_payment_repository.dart';
import '../../../dashboard/domain/dashboard_data.dart';

/// Loads backend loan summaries for one borrower.
final borrowerLoansProvider = FutureProvider.autoDispose
    .family<List<Loan>, String>((ref, borrowerId) async {
      final repository = ref.watch(remoteLoanRepositoryProvider);
      return repository.getLoans(borrowerId: borrowerId);
    });

/// Loads one backend loan together with its persisted installment schedule.
final loanDetailProvider = FutureProvider.autoDispose.family<Loan, String>((
  ref,
  loanId,
) {
  return ref.watch(remoteLoanRepositoryProvider).getLoan(loanId);
});

/// Loads the immutable payment ledger for one loan.
final loanPaymentsProvider = FutureProvider.autoDispose
    .family<List<LoanPayment>, String>((ref, loanId) {
      return ref.watch(remotePaymentRepositoryProvider).history(loanId);
    });

/// All overdue loans with resolved borrower names and computed fields.
final overdueLoansProvider = FutureProvider.autoDispose<List<OverdueLoanItem>>((
  ref,
) async {
  final loanRepo = ref.watch(remoteLoanRepositoryProvider);
  final borrowerRepo = ref.watch(borrowerRepositoryProvider);

  final loans = await loanRepo.getLoans(status: 'Overdue');
  final borrowerMap = <String, String>{};
  final results = <OverdueLoanItem>[];

  for (final loan in loans) {
    final name = borrowerMap[loan.borrowerId];
    if (name == null) {
      final borrower = await borrowerRepo.getBorrower(loan.borrowerId);
      final resolved = borrower?.fullName ?? loan.borrowerId;
      borrowerMap[loan.borrowerId] = resolved;
    }
    final borrowerName = borrowerMap[loan.borrowerId]!;

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

/// Today's due collection items with progress totals.
final todaysCollectionsProvider = FutureProvider.autoDispose<TodaysCollectionData>((
  ref,
) async {
  final loanRepo = ref.watch(remoteLoanRepositoryProvider);
  final borrowerRepo = ref.watch(borrowerRepositoryProvider);

  final allLoans = await loanRepo.getLoans();
  final activeLoans = allLoans
      .where((l) => l.status == 'Active' || l.status == 'Overdue')
      .toList();

  final today = DateTime.now();
  final todayStr =
      '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

  final dueItems = <DashboardDueItem>[];
  double totalDueToday = 0;
  int totalDueCount = 0;
  double totalCollectedToday = 0;

  final borrowerMap = <String, String>{};

  Future<String> resolveName(String borrowerId) async {
    final name = borrowerMap[borrowerId];
    if (name != null) return name;
    final borrower = await borrowerRepo.getBorrower(borrowerId);
    final resolved = borrower?.fullName ?? borrowerId;
    borrowerMap[borrowerId] = resolved;
    return resolved;
  }

  for (final loan in activeLoans.take(50)) {
    try {
      final detail = await loanRepo.getLoan(loan.id);

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

/// All loans with resolved borrower names.
final allLoansProvider = FutureProvider.autoDispose<List<LoanWithBorrower>>((
  ref,
) async {
  final loanRepo = ref.watch(remoteLoanRepositoryProvider);
  final borrowerRepo = ref.watch(borrowerRepositoryProvider);

  final loans = await loanRepo.getLoans();
  final borrowerMap = <String, String>{};
  final results = <LoanWithBorrower>[];

  for (final loan in loans) {
    var name = borrowerMap[loan.borrowerId];
    if (name == null) {
      final borrower = await borrowerRepo.getBorrower(loan.borrowerId);
      final rawName = borrower?.fullName;
      if (rawName != null && rawName.trim().isNotEmpty) {
        name = rawName;
      } else {
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
