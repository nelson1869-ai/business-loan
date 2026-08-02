import 'package:equatable/equatable.dart';

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
      principalAmount: (json['principalAmount'] as num).toDouble(),
      totalRepayable: (json['totalRepayable'] as num).toDouble(),
      amountPaid: (json['amountPaid'] as num).toDouble(),
      outstandingBalance: (json['outstandingBalance'] as num).toDouble(),
      installmentAmount: (json['installmentAmount'] as num).toDouble(),
      paymentFrequency: json['paymentFrequency'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      maturityDate: DateTime.parse(json['maturityDate'] as String),
      nextDueDate: json['nextDueDate'] != null
          ? DateTime.parse(json['nextDueDate'] as String)
          : null,
      nextPaymentAmount: (json['nextPaymentAmount'] as num).toDouble(),
      isOverdue: json['isOverdue'] as bool,
      overdueAmount: (json['overdueAmount'] as num).toDouble(),
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
      total: (json['total'] as num).toInt(),
      offset: (json['offset'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
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
      principalAmount: (json['principalAmount'] as num).toDouble(),
      interestAmount: (json['interestAmount'] as num).toDouble(),
      feesAmount: (json['feesAmount'] as num).toDouble(),
      totalRepayable: (json['totalRepayable'] as num).toDouble(),
      amountPaid: (json['amountPaid'] as num).toDouble(),
      outstandingBalance: (json['outstandingBalance'] as num).toDouble(),
      overdueAmount: (json['overdueAmount'] as num).toDouble(),
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
      installmentCount: (json['installmentCount'] as num).toInt(),
      installmentAmount: (json['installmentAmount'] as num).toDouble(),
      interestRate: (json['interestRate'] as num).toDouble(),
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
      installmentNumber: (json['installmentNumber'] as num).toInt(),
      dueDate: DateTime.parse(json['dueDate'] as String),
      amountDue: (json['amountDue'] as num).toDouble(),
      amountPaid: (json['amountPaid'] as num).toDouble(),
      remainingAmount: (json['remainingAmount'] as num).toDouble(),
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
        json['financialSummary'] as Map<String, dynamic>,
      ),
      terms: BorrowerLoanTerms.fromJson(
        json['terms'] as Map<String, dynamic>,
      ),
      nextInstallment: json['nextInstallment'] != null
          ? BorrowerNextInstallment.fromJson(
              json['nextInstallment'] as Map<String, dynamic>,
            )
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

  BorrowerLoanDetail copyWith({
    String? id,
    String? loanReference,
    String? status,
    BorrowerLoanFinancialSummary? financialSummary,
    BorrowerLoanTerms? terms,
    BorrowerNextInstallment? nextInstallment,
    DateTime? lastUpdated,
    bool? isFromCache,
  }) {
    return BorrowerLoanDetail(
      id: id ?? this.id,
      loanReference: loanReference ?? this.loanReference,
      status: status ?? this.status,
      financialSummary: financialSummary ?? this.financialSummary,
      terms: terms ?? this.terms,
      nextInstallment: nextInstallment ?? this.nextInstallment,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }

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
