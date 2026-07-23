/// Calculated loan quote returned without creating database records.
class LoanQuote {
  const LoanQuote({
    required this.regularPaymentAmount,
    required this.totalInterest,
    required this.totalRepayment,
    required this.numberOfPayments,
    required this.finalDueDate,
  });

  final String regularPaymentAmount;
  final String totalInterest;
  final String totalRepayment;
  final int numberOfPayments;
  final String finalDueDate;

  factory LoanQuote.fromJson(Map<String, dynamic> json) => LoanQuote(
    regularPaymentAmount: json['regularPaymentAmount'].toString(),
    totalInterest: json['totalInterest'].toString(),
    totalRepayment: json['totalRepayment'].toString(),
    numberOfPayments: json['numberOfPayments'] as int,
    finalDueDate: json['finalDueDate'] as String,
  );
}
