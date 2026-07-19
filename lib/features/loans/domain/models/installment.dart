/// Immutable expected payment returned by the backend loan schedule.
class Installment {
  /// Creates one installment snapshot.
  const Installment({
    required this.id,
    required this.loanId,
    required this.installmentNumber,
    required this.dueDate,
    required this.expectedPayment,
    required this.expectedInterest,
    required this.expectedPrincipal,
    required this.expectedRemainingPrincipal,
    required this.paidAmount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String loanId;
  final int installmentNumber;
  final String dueDate;
  final String expectedPayment;
  final String expectedInterest;
  final String expectedPrincipal;
  final String expectedRemainingPrincipal;
  final String paidAmount;
  final String status;
  final String createdAt;

  /// Parses the backend's camel-case installment response.
  factory Installment.fromJson(Map<String, dynamic> json) {
    return Installment(
      id: _requiredString(json, 'id'),
      loanId: _requiredString(json, 'loanId'),
      installmentNumber: _requiredInt(json, 'installmentNumber'),
      dueDate: _requiredDate(json, 'dueDate'),
      expectedPayment: _requiredDecimal(json, 'expectedPayment'),
      expectedInterest: _requiredDecimal(json, 'expectedInterest'),
      expectedPrincipal: _requiredDecimal(json, 'expectedPrincipal'),
      expectedRemainingPrincipal: _requiredDecimal(
        json,
        'expectedRemainingPrincipal',
      ),
      paidAmount: _requiredDecimal(json, 'paidAmount'),
      status: _requiredString(json, 'status'),
      createdAt: _requiredDate(json, 'createdAt'),
    );
  }

  /// Converts this snapshot to the backend's camel-case representation.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'loanId': loanId,
    'installmentNumber': installmentNumber,
    'dueDate': dueDate,
    'expectedPayment': expectedPayment,
    'expectedInterest': expectedInterest,
    'expectedPrincipal': expectedPrincipal,
    'expectedRemainingPrincipal': expectedRemainingPrincipal,
    'paidAmount': paidAmount,
    'status': status,
    'createdAt': createdAt,
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
  if (decimalPattern.hasMatch(value)) return value;
  throw FormatException('$key must be an exact decimal string');
}

String _requiredDate(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  if (DateTime.tryParse(value) != null) return value;
  throw FormatException('$key must be an ISO-8601 date');
}

final RegExp decimalPattern = RegExp(r'^-?\d+(?:\.\d+)?$');
