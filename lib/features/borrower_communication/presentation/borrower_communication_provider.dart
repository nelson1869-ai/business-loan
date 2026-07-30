import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../borrowers/data/borrower_repository.dart';
import '../../borrowers/domain/borrower_model.dart';
import '../../loans/data/repositories/local_loan_repository.dart';
import '../../loans/domain/models/loan.dart';
import '../../loans/domain/models/payment.dart';
import '../domain/borrower_communication_context.dart';

class BorrowerCommunicationRequest {
  const BorrowerCommunicationRequest({
    required this.borrowerId,
    this.borrower,
    this.loan,
    this.payment,
  });

  final String borrowerId;
  final Borrower? borrower;
  final Loan? loan;
  final LoanPayment? payment;
}

/// Loads the communication snapshot exclusively from local data.
final borrowerCommunicationContextProvider = FutureProvider.autoDispose
    .family<BorrowerCommunicationContext, BorrowerCommunicationRequest>((
      ref,
      request,
    ) async {
      final borrower =
          request.borrower ??
          await ref
              .watch(borrowerRepositoryProvider)
              .getBorrower(request.borrowerId);
      if (borrower == null) {
        throw StateError('Borrower details are unavailable on this device.');
      }
      final localLoans = ref.watch(localLoanRepositoryProvider);
      final loan =
          request.loan ??
          (await localLoans.getLoans(borrowerId: request.borrowerId))
              .where(
                (item) => item.status == 'Active' || item.status == 'Overdue',
              )
              .firstOrNull;
      final payments = loan == null
          ? const <LoanPayment>[]
          : await localLoans.getPayments(loan.id);
      return BorrowerCommunicationContext(
        borrower: borrower,
        loan: loan,
        payment: request.payment,
        payments: payments,
      );
    });
