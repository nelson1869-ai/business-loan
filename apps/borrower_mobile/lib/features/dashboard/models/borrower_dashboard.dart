import 'package:equatable/equatable.dart';

double _doubleFromJson(Object? value, String fieldName) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Invalid numeric value for $fieldName');
}

int _intFromJson(Object? value, String fieldName) {
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = num.tryParse(value);
    if (parsed != null) return parsed.toInt();
  }
  throw FormatException('Invalid integer value for $fieldName');
}

class BorrowerInfo extends Equatable {
  final String id;
  final String firstName;
  final String lastName;

  const BorrowerInfo({
    required this.id,
    required this.firstName,
    required this.lastName,
  });

  factory BorrowerInfo.fromJson(Map<String, dynamic> json) {
    return BorrowerInfo(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
      };

  @override
  List<Object?> get props => [id, firstName, lastName];
}

class DashboardSummary extends Equatable {
  final int activeLoanCount;
  final double totalOutstandingBalance;
  final double nextPaymentAmount;
  final DateTime? nextDueDate;
  final double overdueAmount;
  final String loanStatus;
  final String paymentStatus;

  const DashboardSummary({
    required this.activeLoanCount,
    required this.totalOutstandingBalance,
    required this.nextPaymentAmount,
    this.nextDueDate,
    required this.overdueAmount,
    required this.loanStatus,
    required this.paymentStatus,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      activeLoanCount:
          _intFromJson(json['activeLoanCount'], 'activeLoanCount'),
      totalOutstandingBalance: _doubleFromJson(
        json['totalOutstandingBalance'],
        'totalOutstandingBalance',
      ),
      nextPaymentAmount:
          _doubleFromJson(json['nextPaymentAmount'], 'nextPaymentAmount'),
      nextDueDate: json['nextDueDate'] != null
          ? DateTime.parse(json['nextDueDate'] as String)
          : null,
      overdueAmount: _doubleFromJson(json['overdueAmount'], 'overdueAmount'),
      loanStatus: json['loanStatus'] as String,
      paymentStatus: json['paymentStatus'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'activeLoanCount': activeLoanCount,
        'totalOutstandingBalance': totalOutstandingBalance,
        'nextPaymentAmount': nextPaymentAmount,
        'nextDueDate': nextDueDate?.toIso8601String(),
        'overdueAmount': overdueAmount,
        'loanStatus': loanStatus,
        'paymentStatus': paymentStatus,
      };

  @override
  List<Object?> get props => [
        activeLoanCount,
        totalOutstandingBalance,
        nextPaymentAmount,
        nextDueDate,
        overdueAmount,
        loanStatus,
        paymentStatus,
      ];
}

class DashboardRecentPayment extends Equatable {
  final String id;
  final double amount;
  final DateTime effectiveDate;
  final String entryType;
  final String receiptNumber;

  const DashboardRecentPayment({
    required this.id,
    required this.amount,
    required this.effectiveDate,
    required this.entryType,
    required this.receiptNumber,
  });

  factory DashboardRecentPayment.fromJson(Map<String, dynamic> json) {
    return DashboardRecentPayment(
      id: json['id'] as String,
      amount: _doubleFromJson(json['amount'], 'amount'),
      effectiveDate: DateTime.parse(json['effectiveDate'] as String),
      entryType: json['entryType'] as String,
      receiptNumber: json['receiptNumber'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'effectiveDate': effectiveDate.toIso8601String(),
        'entryType': entryType,
        'receiptNumber': receiptNumber,
      };

  @override
  List<Object?> get props =>
      [id, amount, effectiveDate, entryType, receiptNumber];
}

class BorrowerDashboard extends Equatable {
  final BorrowerInfo borrower;
  final DashboardSummary summary;
  final DashboardRecentPayment? recentPayment;
  final DateTime lastUpdated;
  final bool isFromCache;

  const BorrowerDashboard({
    required this.borrower,
    required this.summary,
    this.recentPayment,
    required this.lastUpdated,
    this.isFromCache = false,
  });

  factory BorrowerDashboard.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
  }) {
    return BorrowerDashboard(
      borrower: BorrowerInfo.fromJson(json['borrower'] as Map<String, dynamic>),
      summary:
          DashboardSummary.fromJson(json['summary'] as Map<String, dynamic>),
      recentPayment: json['recentPayment'] != null
          ? DashboardRecentPayment.fromJson(
              json['recentPayment'] as Map<String, dynamic>)
          : null,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      isFromCache: isFromCache,
    );
  }

  Map<String, dynamic> toJson() => {
        'borrower': borrower.toJson(),
        'summary': summary.toJson(),
        'recentPayment': recentPayment?.toJson(),
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  BorrowerDashboard copyWith({
    BorrowerInfo? borrower,
    DashboardSummary? summary,
    DashboardRecentPayment? recentPayment,
    DateTime? lastUpdated,
    bool? isFromCache,
  }) {
    return BorrowerDashboard(
      borrower: borrower ?? this.borrower,
      summary: summary ?? this.summary,
      recentPayment: recentPayment ?? this.recentPayment,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }

  @override
  List<Object?> get props =>
      [borrower, summary, recentPayment, lastUpdated, isFromCache];
}
