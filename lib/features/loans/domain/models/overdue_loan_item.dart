import 'loan.dart';

class OverdueLoanItem {
  const OverdueLoanItem({
    required this.loan,
    required this.borrowerName,
    required this.daysOverdue,
    required this.penaltyInterest,
  });

  final Loan loan;
  final String borrowerName;
  final int daysOverdue;
  final String penaltyInterest;
}
