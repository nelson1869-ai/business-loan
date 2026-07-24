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
  /// applied to a future installment.  Populated from the backend's
  /// [unappliedCredit] field on the loan-detail response.
  final String unappliedCredit;

  final List<Installment> installments;

  /// Parses either a loan-list item or a loan-detail response.
  factory Loan.fromJson(Map<String, dynamic> json) {
    final rawInstallments = json['installments'];
    final List<dynamic> installmentRows;
    if (rawInstallments == null) {
      installmentRows = const <dynamic>[];
    } else if (rawInstallments is List<dynamic>) {
      installmentRows = rawInstallments;
    } else {
      throw const FormatException('installments must be a list');
    }

    return Loan(
      id: _requiredString(json, 'id'),
      requestId: _requiredString(json, 'requestId'),
      borrowerId: _requiredString(json, 'borrowerId'),
      createdByUserId: _requiredString(json, 'createdByUserId'),
      originalPrincipal: _requiredDecimal(json, 'originalPrincipal'),
      outstandingPrincipal: _requiredDecimal(json, 'outstandingPrincipal'),
      monthlyRate: _requiredDecimal(json, 'monthlyRate'),
      termMonths: _requiredInt(json, 'termMonths'),
      paymentsPerMonth: _requiredInt(json, 'paymentsPerMonth'),
      numberOfPayments: _requiredInt(json, 'numberOfPayments'),
      regularPaymentAmount: _requiredDecimal(json, 'regularPaymentAmount'),
      calculationMethod: _requiredString(json, 'calculationMethod'),
      startDate: _requiredDate(json, 'startDate'),
      firstDueDate: _requiredDate(json, 'firstDueDate'),
      finalDueDate: _requiredDate(json, 'finalDueDate'),
      status: _requiredString(json, 'status'),
      createdAt: _requiredDate(json, 'createdAt'),
      unappliedCredit: _optionalDecimal(json, 'unappliedCredit'),
      installments: installmentRows.map<Installment>((dynamic item) {
        if (item is! Map<dynamic, dynamic>) {
          throw const FormatException('installment must be a JSON object');
        }
        return Installment.fromJson(Map<String, dynamic>.from(item));
      }),
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

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$key must be a non-empty string');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('$key must be an integer');
}

String _requiredDecimal(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  if (RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(value)) return value;
  throw FormatException('$key must be an exact decimal string');
}

String _requiredDate(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  if (DateTime.tryParse(value) != null) return value;
  throw FormatException('$key must be an ISO-8601 date');
}

/// Returns the decimal string at [key], or `'0.00'` when the field is absent.
/// Used for fields that older or list endpoints may omit.
String _optionalDecimal(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return '0.00';
  final str = value.toString();
  if (RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(str)) return str;
  return '0.00';
}
