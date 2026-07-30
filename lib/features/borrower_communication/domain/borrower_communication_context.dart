import '../../borrowers/domain/borrower_model.dart';
import '../../loans/domain/models/loan.dart';
import '../../loans/domain/models/payment.dart';

/// Local borrower-facing data used to compose messages and documents.
class BorrowerCommunicationContext {
  const BorrowerCommunicationContext({
    required this.borrower,
    this.loan,
    this.payment,
    this.payments = const <LoanPayment>[],
  });

  final Borrower borrower;
  final Loan? loan;
  final LoanPayment? payment;
  final List<LoanPayment> payments;
}
