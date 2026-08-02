import 'package:equatable/equatable.dart';

double _doubleFromJson(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  return 0.0;
}

int _intFromJson(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = num.tryParse(value);
    if (parsed != null) return parsed.toInt();
  }
  return 0;
}

class BorrowerPaymentListItem extends Equatable {
  final String id;
  final String receiptNumber;
  final DateTime effectiveDate;
  final double amount;
  final String entryType;
  final String status;
  final DateTime createdAt;

  const BorrowerPaymentListItem({
    required this.id,
    required this.receiptNumber,
    required this.effectiveDate,
    required this.amount,
    required this.entryType,
    required this.status,
    required this.createdAt,
  });

  factory BorrowerPaymentListItem.fromJson(Map<String, dynamic> json) {
    return BorrowerPaymentListItem(
      id: json['id'] as String,
      receiptNumber: json['receiptNumber'] as String,
      effectiveDate: DateTime.parse(json['effectiveDate'] as String),
      amount: _doubleFromJson(json['amount']),
      entryType: json['entryType'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'receiptNumber': receiptNumber,
        'effectiveDate': effectiveDate.toIso8601String(),
        'amount': amount,
        'entryType': entryType,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        receiptNumber,
        effectiveDate,
        amount,
        entryType,
        status,
        createdAt,
      ];
}

class BorrowerPaymentHistory extends Equatable {
  final List<BorrowerPaymentListItem> items;
  final int totalCount;
  final bool isFromCache;

  const BorrowerPaymentHistory({
    required this.items,
    required this.totalCount,
    this.isFromCache = false,
  });

  factory BorrowerPaymentHistory.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
  }) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return BorrowerPaymentHistory(
      items: rawItems
          .map((e) =>
              BorrowerPaymentListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: _intFromJson(json['totalCount']),
      isFromCache: isFromCache,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'totalCount': totalCount,
      };

  @override
  List<Object?> get props => [items, totalCount, isFromCache];
}

class BorrowerReceiptDetail extends Equatable {
  final String receiptNumber;
  final String paymentId;
  final String loanId;
  final String loanReference;
  final DateTime paymentDate;
  final double amountReceived;
  final double principalPaid;
  final double interestPaid;
  final double penaltyPaid;
  final double unappliedCredit;
  final double remainingBalance;
  final String entryType;
  final String status;
  final DateTime recordedAt;
  final bool isFromCache;

  const BorrowerReceiptDetail({
    required this.receiptNumber,
    required this.paymentId,
    required this.loanId,
    required this.loanReference,
    required this.paymentDate,
    required this.amountReceived,
    required this.principalPaid,
    required this.interestPaid,
    required this.penaltyPaid,
    required this.unappliedCredit,
    required this.remainingBalance,
    required this.entryType,
    required this.status,
    required this.recordedAt,
    this.isFromCache = false,
  });

  factory BorrowerReceiptDetail.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
  }) {
    return BorrowerReceiptDetail(
      receiptNumber: json['receiptNumber'] as String,
      paymentId: json['paymentId'] as String,
      loanId: json['loanId'] as String,
      loanReference: json['loanReference'] as String,
      paymentDate: DateTime.parse(json['paymentDate'] as String),
      amountReceived: _doubleFromJson(json['amountReceived']),
      principalPaid: _doubleFromJson(json['principalPaid']),
      interestPaid: _doubleFromJson(json['interestPaid']),
      penaltyPaid: _doubleFromJson(json['penaltyPaid']),
      unappliedCredit: _doubleFromJson(json['unappliedCredit']),
      remainingBalance: _doubleFromJson(json['remainingBalance']),
      entryType: json['entryType'] as String,
      status: json['status'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      isFromCache: isFromCache,
    );
  }

  Map<String, dynamic> toJson() => {
        'receiptNumber': receiptNumber,
        'paymentId': paymentId,
        'loanId': loanId,
        'loanReference': loanReference,
        'paymentDate': paymentDate.toIso8601String(),
        'amountReceived': amountReceived,
        'principalPaid': principalPaid,
        'interestPaid': interestPaid,
        'penaltyPaid': penaltyPaid,
        'unappliedCredit': unappliedCredit,
        'remainingBalance': remainingBalance,
        'entryType': entryType,
        'status': status,
        'recordedAt': recordedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        receiptNumber,
        paymentId,
        loanId,
        loanReference,
        paymentDate,
        amountReceived,
        principalPaid,
        interestPaid,
        penaltyPaid,
        unappliedCredit,
        remainingBalance,
        entryType,
        status,
        recordedAt,
        isFromCache,
      ];
}
