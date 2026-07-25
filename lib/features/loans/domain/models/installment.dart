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

  /// Parses the backend's camel-case or snake-case installment response.
  factory Installment.fromJson(Map<String, dynamic> json) {
    return Installment(
      id: _parseString(json, 'id'),
      loanId: _parseString(json, 'loanId'),
      installmentNumber: _parseInt(json, 'installmentNumber'),
      dueDate: _parseDate(json, 'dueDate'),
      expectedPayment: _parseDecimal(json, 'expectedPayment'),
      expectedInterest: _parseDecimal(json, 'expectedInterest'),
      expectedPrincipal: _parseDecimal(json, 'expectedPrincipal'),
      expectedRemainingPrincipal: _parseDecimal(
        json,
        'expectedRemainingPrincipal',
      ),
      paidAmount: _parseDecimal(json, 'paidAmount'),
      status: _parseString(json, 'status', fallback: 'Scheduled'),
      createdAt: _parseDate(json, 'createdAt'),
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

String _parseString(
  Map<String, dynamic> json,
  String key, {
  String fallback = '',
}) {
  final value = json[key] ?? json[_toSnake(key)];
  if (value != null && value.toString().isNotEmpty) return value.toString();
  return fallback;
}

int _parseInt(Map<String, dynamic> json, String key, {int fallback = 1}) {
  final value = json[key] ?? json[_toSnake(key)];
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _parseDecimal(
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

String _parseDate(
  Map<String, dynamic> json,
  String key, {
  String fallback = '',
}) {
  final value = json[key] ?? json[_toSnake(key)];
  if (value != null && value.toString().isNotEmpty) return value.toString();
  return fallback.isNotEmpty ? fallback : DateTime.now().toIso8601String();
}

String _toSnake(String str) {
  return str.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => '_${match.group(0)!.toLowerCase()}',
  );
}
