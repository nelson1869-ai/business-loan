import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/remote_loan_repository.dart';
import '../../domain/models/loan.dart';

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
