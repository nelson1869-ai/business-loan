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

class BorrowerLoanListItem extends Equatable {
  final String id;
  final String loanReference;
  final String status;
  final double principalAmount;
  final double totalRepayable;
  final double amountPaid;
  final double outstandingBalance;
  final double installmentAmount;
  final String paymentFrequency;
  final DateTime startDate;
  final DateTime maturityDate;
  final DateTime? nextDueDate;
  final double nextPaymentAmount;
  final bool isOverdue;
  final double overdueAmount;
  final DateTime updatedAt;

  const BorrowerLoanListItem({
    required this.id,
    required this.loanReference,
    required this.status,
    required this.principalAmount,
    required this.totalRepayable,
    required this.amountPaid,
    required this.outstandingBalance,
    required this.installmentAmount,
    required this.paymentFrequency,
    required this.startDate,
    required this.maturityDate,
    this.nextDueDate,
    required this.nextPaymentAmount,
    required this.isOverdue,
    required this.overdueAmount,
    required this.updatedAt,
  });

  factory BorrowerLoanListItem.fromJson(Map<String, dynamic> json) {
    return BorrowerLoanListItem(
      id: json['id'] as String,
      loanReference: json['loanReference'] as String,
      status: json['status'] as String,
      principalAmount: _doubleFromJson(json['principalAmount']),
      totalRepayable: _doubleFromJson(json['totalRepayable']),
      amountPaid: _doubleFromJson(json['amountPaid']),
      outstandingBalance: _doubleFromJson(json['outstandingBalance']),
      installmentAmount: _doubleFromJson(json['installmentAmount']),
      paymentFrequency: json['paymentFrequency'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      maturityDate: DateTime.parse(json['maturityDate'] as String),
      nextDueDate: json['nextDueDate'] != null
          ? DateTime.parse(json['nextDueDate'] as String)
          : null,
      nextPaymentAmount: _doubleFromJson(json['nextPaymentAmount']),
      isOverdue: json['isOverdue'] as bool,
      overdueAmount: _doubleFromJson(json['overdueAmount']),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'loanReference': loanReference,
        'status': status,
        'principalAmount': principalAmount,
        'totalRepayable': totalRepayable,
        'amountPaid': amountPaid,
        'outstandingBalance': outstandingBalance,
        'installmentAmount': installmentAmount,
        'paymentFrequency': paymentFrequency,
        'startDate': startDate.toIso8601String(),
        'maturityDate': maturityDate.toIso8601String(),
        'nextDueDate': nextDueDate?.toIso8601String(),
        'nextPaymentAmount': nextPaymentAmount,
        'isOverdue': isOverdue,
        'overdueAmount': overdueAmount,
        'updatedAt': updatedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        loanReference,
        status,
        principalAmount,
        totalRepayable,
        amountPaid,
        outstandingBalance,
        installmentAmount,
        paymentFrequency,
        startDate,
        maturityDate,
        nextDueDate,
        nextPaymentAmount,
        isOverdue,
        overdueAmount,
        updatedAt,
      ];
}

class BorrowerLoanListResponse extends Equatable {
  final List<BorrowerLoanListItem> items;
  final int total;
  final int offset;
  final int limit;

  const BorrowerLoanListResponse({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  factory BorrowerLoanListResponse.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return BorrowerLoanListResponse(
      items: list
          .map((e) => BorrowerLoanListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: _intFromJson(json['total']),
      offset: _intFromJson(json['offset']),
      limit: _intFromJson(json['limit']),
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
        'offset': offset,
        'limit': limit,
      };

  @override
  List<Object?> get props => [items, total, offset, limit];
}

class BorrowerLoanFinancialSummary extends Equatable {
  final double principalAmount;
  final double interestAmount;
  final double feesAmount;
  final double totalRepayable;
  final double amountPaid;
  final double outstandingBalance;
  final double overdueAmount;

  const BorrowerLoanFinancialSummary({
    required this.principalAmount,
    required this.interestAmount,
    required this.feesAmount,
    required this.totalRepayable,
    required this.amountPaid,
    required this.outstandingBalance,
    required this.overdueAmount,
  });

  factory BorrowerLoanFinancialSummary.fromJson(Map<String, dynamic> json) {
    return BorrowerLoanFinancialSummary(
      principalAmount: _doubleFromJson(json['principalAmount']),
      interestAmount: _doubleFromJson(json['interestAmount']),
      feesAmount: _doubleFromJson(json['feesAmount']),
      totalRepayable: _doubleFromJson(json['totalRepayable']),
      amountPaid: _doubleFromJson(json['amountPaid']),
      outstandingBalance: _doubleFromJson(json['outstandingBalance']),
      overdueAmount: _doubleFromJson(json['overdueAmount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'principalAmount': principalAmount,
        'interestAmount': interestAmount,
        'feesAmount': feesAmount,
        'totalRepayable': totalRepayable,
        'amountPaid': amountPaid,
        'outstandingBalance': outstandingBalance,
        'overdueAmount': overdueAmount,
      };

  @override
  List<Object?> get props => [
        principalAmount,
        interestAmount,
        feesAmount,
        totalRepayable,
        amountPaid,
        outstandingBalance,
        overdueAmount,
      ];
}

class BorrowerLoanTerms extends Equatable {
  final String paymentFrequency;
  final int installmentCount;
  final double installmentAmount;
  final double interestRate;
  final DateTime startDate;
  final DateTime maturityDate;

  const BorrowerLoanTerms({
    required this.paymentFrequency,
    required this.installmentCount,
    required this.installmentAmount,
    required this.interestRate,
    required this.startDate,
    required this.maturityDate,
  });

  factory BorrowerLoanTerms.fromJson(Map<String, dynamic> json) {
    return BorrowerLoanTerms(
      paymentFrequency: json['paymentFrequency'] as String,
      installmentCount: _intFromJson(json['installmentCount']),
      installmentAmount: _doubleFromJson(json['installmentAmount']),
      interestRate: _doubleFromJson(json['interestRate']),
      startDate: DateTime.parse(json['startDate'] as String),
      maturityDate: DateTime.parse(json['maturityDate'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'paymentFrequency': paymentFrequency,
        'installmentCount': installmentCount,
        'installmentAmount': installmentAmount,
        'interestRate': interestRate,
        'startDate': startDate.toIso8601String(),
        'maturityDate': maturityDate.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        paymentFrequency,
        installmentCount,
        installmentAmount,
        interestRate,
        startDate,
        maturityDate,
      ];
}

class BorrowerNextInstallment extends Equatable {
  final int installmentNumber;
  final DateTime dueDate;
  final double amountDue;
  final double amountPaid;
  final double remainingAmount;
  final String status;

  const BorrowerNextInstallment({
    required this.installmentNumber,
    required this.dueDate,
    required this.amountDue,
    required this.amountPaid,
    required this.remainingAmount,
    required this.status,
  });

  factory BorrowerNextInstallment.fromJson(Map<String, dynamic> json) {
    return BorrowerNextInstallment(
      installmentNumber: _intFromJson(json['installmentNumber']),
      dueDate: DateTime.parse(json['dueDate'] as String),
      amountDue: _doubleFromJson(json['amountDue']),
      amountPaid: _doubleFromJson(json['amountPaid']),
      remainingAmount: _doubleFromJson(json['remainingAmount']),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'installmentNumber': installmentNumber,
        'dueDate': dueDate.toIso8601String(),
        'amountDue': amountDue,
        'amountPaid': amountPaid,
        'remainingAmount': remainingAmount,
        'status': status,
      };

  @override
  List<Object?> get props => [
        installmentNumber,
        dueDate,
        amountDue,
        amountPaid,
        remainingAmount,
        status,
      ];
}

class BorrowerLoanDetail extends Equatable {
  final String id;
  final String loanReference;
  final String status;
  final BorrowerLoanFinancialSummary financialSummary;
  final BorrowerLoanTerms terms;
  final BorrowerNextInstallment? nextInstallment;
  final DateTime lastUpdated;
  final bool isFromCache;

  const BorrowerLoanDetail({
    required this.id,
    required this.loanReference,
    required this.status,
    required this.financialSummary,
    required this.terms,
    this.nextInstallment,
    required this.lastUpdated,
    this.isFromCache = false,
  });

  factory BorrowerLoanDetail.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
  }) {
    return BorrowerLoanDetail(
      id: json['id'] as String,
      loanReference: json['loanReference'] as String,
      status: json['status'] as String,
      financialSummary: BorrowerLoanFinancialSummary.fromJson(
          json['financialSummary'] as Map<String, dynamic>),
      terms: BorrowerLoanTerms.fromJson(
          json['terms'] as Map<String, dynamic>),
      nextInstallment: json['nextInstallment'] != null
          ? BorrowerNextInstallment.fromJson(
              json['nextInstallment'] as Map<String, dynamic>)
          : null,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      isFromCache: isFromCache,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'loanReference': loanReference,
        'status': status,
        'financialSummary': financialSummary.toJson(),
        'terms': terms.toJson(),
        'nextInstallment': nextInstallment?.toJson(),
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        loanReference,
        status,
        financialSummary,
        terms,
        nextInstallment,
        lastUpdated,
        isFromCache,
      ];
}

class BorrowerInstallmentItem extends Equatable {
  final int installmentNumber;
  final DateTime dueDate;
  final double expectedPayment;
  final double expectedPrincipal;
  final double expectedInterest;
  final double paidAmount;
  final double remainingBalance;
  final String status;

  const BorrowerInstallmentItem({
    required this.installmentNumber,
    required this.dueDate,
    required this.expectedPayment,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.paidAmount,
    required this.remainingBalance,
    required this.status,
  });

  factory BorrowerInstallmentItem.fromJson(Map<String, dynamic> json) {
    return BorrowerInstallmentItem(
      installmentNumber: _intFromJson(json['installmentNumber']),
      dueDate: DateTime.parse(json['dueDate'] as String),
      expectedPayment: _doubleFromJson(json['expectedPayment']),
      expectedPrincipal: _doubleFromJson(json['expectedPrincipal']),
      expectedInterest: _doubleFromJson(json['expectedInterest']),
      paidAmount: _doubleFromJson(json['paidAmount']),
      remainingBalance: _doubleFromJson(json['remainingBalance']),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'installmentNumber': installmentNumber,
        'dueDate': dueDate.toIso8601String(),
        'expectedPayment': expectedPayment,
        'expectedPrincipal': expectedPrincipal,
        'expectedInterest': expectedInterest,
        'paidAmount': paidAmount,
        'remainingBalance': remainingBalance,
        'status': status,
      };

  @override
  List<Object?> get props => [
        installmentNumber,
        dueDate,
        expectedPayment,
        expectedPrincipal,
        expectedInterest,
        paidAmount,
        remainingBalance,
        status,
      ];
}

class BorrowerInstallmentSchedule extends Equatable {
  final String loanId;
  final String loanReference;
  final List<BorrowerInstallmentItem> items;
  final int totalInstallments;
  final int paidInstallmentsCount;
  final bool isFromCache;

  const BorrowerInstallmentSchedule({
    required this.loanId,
    required this.loanReference,
    required this.items,
    required this.totalInstallments,
    required this.paidInstallmentsCount,
    this.isFromCache = false,
  });

  factory BorrowerInstallmentSchedule.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
  }) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return BorrowerInstallmentSchedule(
      loanId: json['loanId'] as String,
      loanReference: json['loanReference'] as String,
      items: rawItems
          .map((e) =>
              BorrowerInstallmentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalInstallments: _intFromJson(json['totalInstallments']),
      paidInstallmentsCount: _intFromJson(json['paidInstallmentsCount']),
      isFromCache: isFromCache,
    );
  }

  Map<String, dynamic> toJson() => {
        'loanId': loanId,
        'loanReference': loanReference,
        'items': items.map((e) => e.toJson()).toList(),
        'totalInstallments': totalInstallments,
        'paidInstallmentsCount': paidInstallmentsCount,
      };

  @override
  List<Object?> get props => [
        loanId,
        loanReference,
        items,
        totalInstallments,
        paidInstallmentsCount,
        isFromCache,
      ];
}
