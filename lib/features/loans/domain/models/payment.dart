/// Authoritative payment allocation returned before confirmation.
class PaymentPreview {
  const PaymentPreview({
    required this.loanId,
    required this.installmentId,
    required this.paymentAmount,
    required this.effectiveDate,
    required this.dueDate,
    required this.daysEarly,
    required this.overdueDays,
    required this.accruedInterest,
    required this.totalInterestBefore,
    required this.principalBefore,
    required this.appliedInterest,
    required this.appliedPrincipal,
    required this.unappliedCredit,
    required this.interestAfter,
    required this.principalAfter,
    required this.amountAboveScheduled,
    required this.nextPeriodInterest,
    required this.isPayoff,
  });

  final String loanId;
  final String installmentId;
  final String paymentAmount;
  final String effectiveDate;
  final String dueDate;
  final int daysEarly;
  final int overdueDays;
  final String accruedInterest;
  final String totalInterestBefore;
  final String principalBefore;
  final String appliedInterest;
  final String appliedPrincipal;
  final String unappliedCredit;
  final String interestAfter;
  final String principalAfter;
  final String amountAboveScheduled;
  final String nextPeriodInterest;
  final bool isPayoff;

  factory PaymentPreview.fromJson(Map<String, dynamic> json) => PaymentPreview(
    loanId: _string(json, 'loanId'),
    installmentId: _string(json, 'installmentId'),
    paymentAmount: _decimal(json, 'paymentAmount'),
    effectiveDate: _string(json, 'effectiveDate'),
    dueDate: _string(json, 'dueDate'),
    daysEarly: _integer(json, 'daysEarly'),
    overdueDays: _integer(json, 'overdueDays'),
    accruedInterest: _decimal(json, 'accruedInterest'),
    totalInterestBefore: _decimal(json, 'totalInterestBefore'),
    principalBefore: _decimal(json, 'principalBefore'),
    appliedInterest: _decimal(json, 'appliedInterest'),
    appliedPrincipal: _decimal(json, 'appliedPrincipal'),
    unappliedCredit: _decimal(json, 'unappliedCredit'),
    interestAfter: _decimal(json, 'interestAfter'),
    principalAfter: _decimal(json, 'principalAfter'),
    amountAboveScheduled: _decimal(json, 'amountAboveScheduled'),
    nextPeriodInterest: _decimal(json, 'nextPeriodInterest'),
    isPayoff: _boolean(json, 'isPayoff'),
  );
}

/// Immutable confirmed payment and its allocation snapshot.
class LoanPayment {
  const LoanPayment({
    required this.id,
    required this.requestId,
    required this.loanId,
    required this.installmentId,
    required this.entryType,
    required this.reversalOfPaymentId,
    required this.amount,
    required this.effectiveDate,
    required this.note,
    required this.createdAt,
    required this.allocation,
  });

  final String id;
  final String requestId;
  final String loanId;
  final String? installmentId;
  final String entryType;
  final String? reversalOfPaymentId;
  final String amount;
  final String effectiveDate;
  final String? note;
  final String createdAt;
  final PaymentAllocation allocation;

  factory LoanPayment.fromJson(Map<String, dynamic> json) => LoanPayment(
    id: _string(json, 'id'),
    requestId: _string(json, 'requestId'),
    loanId: _string(json, 'loanId'),
    installmentId: json['installmentId'] as String?,
    entryType: _string(json, 'entryType'),
    reversalOfPaymentId: json['reversalOfPaymentId'] as String?,
    amount: _decimal(json, 'amount'),
    effectiveDate: _string(json, 'effectiveDate'),
    note: json['note'] as String?,
    createdAt: _string(json, 'createdAt'),
    allocation: PaymentAllocation.fromJson(
      Map<String, dynamic>.from(json['allocation'] as Map),
    ),
  );
}

class PaymentAllocation {
  const PaymentAllocation({
    required this.appliedInterest,
    required this.appliedPrincipal,
    required this.unappliedCredit,
    required this.interestAfter,
    required this.principalAfter,
    required this.overdueDays,
  });

  final String appliedInterest;
  final String appliedPrincipal;
  final String unappliedCredit;
  final String interestAfter;
  final String principalAfter;
  final int overdueDays;

  factory PaymentAllocation.fromJson(Map<String, dynamic> json) =>
      PaymentAllocation(
        appliedInterest: _decimal(json, 'appliedInterest'),
        appliedPrincipal: _decimal(json, 'appliedPrincipal'),
        unappliedCredit: _decimal(json, 'unappliedCredit'),
        interestAfter: _decimal(json, 'interestAfter'),
        principalAfter: _decimal(json, 'principalAfter'),
        overdueDays: _integer(json, 'overdueDays'),
      );
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$key must be a non-empty string');
}

String _decimal(Map<String, dynamic> json, String key) {
  final value = _string(json, key);
  if (RegExp(r'^\d+(?:\.\d+)?$').hasMatch(value)) return value;
  throw FormatException('$key must be an exact decimal string');
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('$key must be an integer');
}

bool _boolean(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('$key must be a boolean');
}
