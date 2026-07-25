import 'dart:collection';

import 'installment.dart';

/// Immutable loan account returned by FastAPI.
class Loan {
  /// Creates one loan snapshot and protects its schedule from mutation.
  Loan({
    required this.id,
    required this.requestId,
    required this.borrowerId,
    required this.createdByUserId,
    required this.originalPrincipal,
    required this.outstandingPrincipal,
    required this.monthlyRate,
    required this.termMonths,
    required this.paymentsPerMonth,
    required this.numberOfPayments,
    required this.regularPaymentAmount,
    required this.calculationMethod,
    required this.startDate,
    required this.firstDueDate,
    required this.finalDueDate,
    required this.status,
    required this.createdAt,
    this.unappliedCredit = '0.00',
    Iterable<Installment> installments = const <Installment>[],
  }) : installments = UnmodifiableListView<Installment>(installments);

  final String id;
  final String requestId;
  final String borrowerId;
  final String createdByUserId;
  final String originalPrincipal;
  final String outstandingPrincipal;
  final String monthlyRate;
  final int termMonths;
  final int paymentsPerMonth;
  final int numberOfPayments;
  final String regularPaymentAmount;
  final String calculationMethod;
  final String startDate;
  final String firstDueDate;
  final String finalDueDate;
  final String status;
  final String createdAt;

  /// Net advance credit currently held for this loan that has not yet been
  /// applied to a future installment. Populated from the backend's
  /// [unappliedCredit] field on the loan-detail response.
  final String unappliedCredit;

  final List<Installment> installments;

  /// Parses either a loan-list item or a loan-detail response.
  factory Loan.fromJson(Map<String, dynamic> json) {
    final rawInstallments = json['installments'];
    final List<dynamic> installmentRows;
    if (rawInstallments is List<dynamic>) {
      installmentRows = rawInstallments;
    } else {
      installmentRows = const <dynamic>[];
    }

    return Loan(
      id: _parseString(json, 'id'),
      requestId: _parseString(json, 'requestId'),
      borrowerId: _parseString(json, 'borrowerId'),
      createdByUserId: _parseString(
        json,
        'createdByUserId',
        fallback: 'system-officer',
      ),
      originalPrincipal: _parseDecimal(json, 'originalPrincipal'),
      outstandingPrincipal: _parseDecimal(json, 'outstandingPrincipal'),
      monthlyRate: _parseDecimal(json, 'monthlyRate'),
      termMonths: _parseInt(json, 'termMonths'),
      paymentsPerMonth: _parseInt(json, 'paymentsPerMonth'),
      numberOfPayments: _parseInt(json, 'numberOfPayments'),
      regularPaymentAmount: _parseDecimal(json, 'regularPaymentAmount'),
      calculationMethod: _parseString(
        json,
        'calculationMethod',
        fallback: 'fixed_periodic_reducing_balance',
      ),
      startDate: _parseDate(json, 'startDate'),
      firstDueDate: _parseDate(json, 'firstDueDate'),
      finalDueDate: _parseDate(json, 'finalDueDate'),
      status: _parseString(json, 'status', fallback: 'Active'),
      createdAt: _parseDate(json, 'createdAt'),
      unappliedCredit: _parseDecimal(json, 'unappliedCredit'),
      installments: installmentRows
          .whereType<Map<dynamic, dynamic>>()
          .map<Installment>(
            (dynamic item) => Installment.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
    );
  }

  /// Converts this snapshot to the backend's camel-case representation.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'requestId': requestId,
    'borrowerId': borrowerId,
    'createdByUserId': createdByUserId,
    'originalPrincipal': originalPrincipal,
    'outstandingPrincipal': outstandingPrincipal,
    'monthlyRate': monthlyRate,
    'termMonths': termMonths,
    'paymentsPerMonth': paymentsPerMonth,
    'numberOfPayments': numberOfPayments,
    'regularPaymentAmount': regularPaymentAmount,
    'calculationMethod': calculationMethod,
    'startDate': startDate,
    'firstDueDate': firstDueDate,
    'finalDueDate': finalDueDate,
    'status': status,
    'createdAt': createdAt,
    'unappliedCredit': unappliedCredit,
    'installments': installments
        .map((Installment installment) => installment.toJson())
        .toList(growable: false),
  };
}

String _parseString(
  Map<String, dynamic> json,
  String key, {
  String fallback = '',
}) {
  final value = json[key] ?? json[_toSnakeCase(key)];
  if (value != null && value.toString().isNotEmpty) return value.toString();
  if (key == 'requestId') return json['id']?.toString() ?? fallback;
  return fallback;
}

int _parseInt(Map<String, dynamic> json, String key) {
  final value = json[key] ?? json[_toSnakeCase(key)];
  if (value is int) return value;
  throw FormatException('$key must be an integer');
}

String _parseDecimal(
  Map<String, dynamic> json,
  String key, {
  String fallback = '0.00',
}) {
  final value = json[key] ?? json[_toSnakeCase(key)];
  if (value == null && key == 'unappliedCredit') return fallback;
  if (value is! String) {
    throw FormatException('$key must be an exact decimal string');
  }
  if (RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(value)) return value;
  throw FormatException('$key must be an exact decimal string');
}

String _parseDate(
  Map<String, dynamic> json,
  String key, {
  String fallback = '',
}) {
  final value = json[key] ?? json[_toSnakeCase(key)];
  if (value != null && value.toString().isNotEmpty) {
    final str = value.toString();
    if (DateTime.tryParse(str) != null) return str;
  }
  return fallback.isNotEmpty ? fallback : DateTime.now().toIso8601String();
}

String _toSnakeCase(String str) {
  return str.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => '_${match.group(0)!.toLowerCase()}',
  );
}
