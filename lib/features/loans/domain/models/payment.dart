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

  factory LoanPayment.fromJson(Map<String, dynamic> json) {
    final rawAlloc = json['allocation'];
    final allocMap = rawAlloc is Map
        ? Map<String, dynamic>.from(rawAlloc)
        : const <String, dynamic>{};
    return LoanPayment(
      id: _string(json, 'id'),
      requestId: _string(json, 'requestId'),
      loanId: _string(json, 'loanId'),
      installmentId: (json['installmentId'] ?? json['installment_id'])
          ?.toString(),
      entryType: _string(json, 'entryType', fallback: 'Payment'),
      reversalOfPaymentId:
          (json['reversalOfPaymentId'] ?? json['reversal_of_payment_id'])
              ?.toString(),
      amount: _decimal(json, 'amount'),
      effectiveDate: _string(json, 'effectiveDate'),
      note: json['note']?.toString(),
      createdAt: _string(json, 'createdAt'),
      allocation: PaymentAllocation.fromJson(allocMap),
    );
  }
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

String _string(Map<String, dynamic> json, String key, {String fallback = ''}) {
  final value = json[key] ?? json[_toSnake(key)];
  if (value != null && value.toString().isNotEmpty) return value.toString();
  if (key == 'requestId') return json['id']?.toString() ?? fallback;
  return fallback;
}

String _decimal(
  Map<String, dynamic> json,
  String key, {
  String fallback = '0.00',
}) {
  final value = json[key] ?? json[_toSnake(key)];
  if (value != null) {
    final str = value.toString();
    if (RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(str)) return str;
    final parsed = double.tryParse(str);
    if (parsed != null) return parsed.toStringAsFixed(2);
  }
  return fallback;
}

int _integer(Map<String, dynamic> json, String key, {int fallback = 0}) {
  final value = json[key] ?? json[_toSnake(key)];
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _boolean(Map<String, dynamic> json, String key, {bool fallback = false}) {
  final value = json[key] ?? json[_toSnake(key)];
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

String _toSnake(String str) {
  return str.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => '_${match.group(0)!.toLowerCase()}',
  );
}
