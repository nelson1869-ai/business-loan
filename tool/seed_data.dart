// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

final _uuid = const Uuid();
final _apiBaseUrl =
    Platform.environment['SEED_API_BASE_URL']?.trim().isNotEmpty == true
    ? Platform.environment['SEED_API_BASE_URL']!.trim()
    : 'http://localhost:8000';
final _username = Platform.environment['SEED_USERNAME']?.trim() ?? '';
final _password = Platform.environment['SEED_PASSWORD'] ?? '';
final _dio = Dio(
  BaseOptions(
    baseUrl: _apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
  ),
);

String _date(DateTime value) =>
    value.toUtc().toIso8601String().split('T').first;

String _timestamp(DateTime value) => value.toUtc().toIso8601String();

DateTime _monthsBefore(DateTime date, int months) {
  return DateTime.utc(date.year, date.month - months, 1);
}

Future<String> _authenticate() async {
  try {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/token',
      data: {'username': _username, 'password': _password},
    );
    final token = response.data?['access_token'] as String;
    _dio.options.headers['Authorization'] = 'Bearer $token';
    return token;
  } on DioException catch (e) {
    print('Status: ${e.response?.statusCode}');
    print('Body: ${e.response?.data}');
    rethrow;
  }
}

Future<void> _resetAllData() async {
  final response = await _dio.post<Map<String, dynamic>>('/api/v1/admin/reset');
  final detail = response.data?['detail'] as String?;
  print(detail ?? 'All existing application data was deleted.');
}

Future<String> _createBorrower({
  required String firstName,
  required String lastName,
  required String nationalId,
  required String phone,
  required String dateOfBirth,
  required String status,
  required String createdAt,
}) async {
  final id = _uuid.v4();
  await _dio.post<void>(
    '/api/v1/borrowers',
    data: {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'nationalId': nationalId,
      'phone': phone,
      'dateOfBirth': dateOfBirth,
      'status': status,
      'createdAt': createdAt,
    },
  );
  print('Created borrower: $firstName $lastName ($status)');
  return id;
}

Future<String> _createLoan({
  required String borrowerId,
  required String originalPrincipal,
  required String monthlyRate,
  required int termMonths,
  required int paymentsPerMonth,
  required String startDate,
  required String firstDueDate,
}) async {
  final requestId = _uuid.v4();
  final response = await _dio.post<Map<String, dynamic>>(
    '/api/v1/loans',
    data: {
      'borrowerId': borrowerId,
      'requestId': requestId,
      'originalPrincipal': originalPrincipal,
      'monthlyRate': monthlyRate,
      'termMonths': termMonths,
      'paymentsPerMonth': paymentsPerMonth,
      'startDate': startDate,
      'firstDueDate': firstDueDate,
    },
  );
  final loanId = response.data!['id'] as String;
  print(
    'Created loan $loanId ($originalPrincipal, ${termMonths}m, $monthlyRate%/mo)',
  );
  return loanId;
}

Future<void> _recordPayment({
  required String loanId,
  required String amount,
  required String effectiveDate,
  String? note,
}) async {
  final requestId = _uuid.v4();
  final response = await _dio.post<Map<String, dynamic>>(
    '/api/v1/loans/$loanId/payments',
    data: {
      'requestId': requestId,
      'amount': amount,
      'effectiveDate': effectiveDate,
      if (note != null && note.isNotEmpty) 'note': note,
    },
  );
  final paymentId = response.data!['id'] as String;
  print('Recorded payment $paymentId: $amount on $effectiveDate');
}

Future<void> _reversePayment({
  required String loanId,
  required String paymentId,
  required String effectiveDate,
  required String reason,
}) async {
  final requestId = _uuid.v4();
  await _dio.post<void>(
    '/api/v1/loans/$loanId/payments/$paymentId/reversal',
    data: {
      'requestId': requestId,
      'effectiveDate': effectiveDate,
      'reason': reason,
    },
  );
  print('Reversed payment $paymentId on $effectiveDate: $reason');
}

Future<void> main(List<String> arguments) async {
  if (!arguments.contains('--reset')) {
    stderr.writeln(
      'Refusing to seed without --reset because this deletes all application data.\n'
      'Usage: dart run tool/seed_data.dart --reset',
    );
    exitCode = 64;
    return;
  }
  if (_username.isEmpty || _password.isEmpty) {
    stderr.writeln(
      'Set SEED_USERNAME and SEED_PASSWORD before running this tool.',
    );
    exitCode = 64;
    return;
  }

  final today = DateTime.now().toUtc();
  final seedId = today.microsecondsSinceEpoch;
  final fiveMonthsAgo = _monthsBefore(today, 5);
  final fourMonthsAgo = _monthsBefore(today, 4);
  final threeMonthsAgo = _monthsBefore(today, 3);
  final twoMonthsAgo = _monthsBefore(today, 2);
  final oneMonthAgo = _monthsBefore(today, 1);
  final thisMonth = _monthsBefore(today, 0);

  print('Target API: $_apiBaseUrl');
  print('=== Authenticating... ===');
  await _authenticate();
  print('Authenticated as $_username');

  print('\n=== Resetting all existing application data... ===');
  await _resetAllData();

  print('\n=== Creating borrowers... ===');

  // 1. John Smith - Active, has loans with mixed payment history
  final john = await _createBorrower(
    firstName: 'John',
    lastName: 'Smith',
    nationalId: 'ID-$seedId-001',
    phone: '+254701234567',
    dateOfBirth: '1990-05-15',
    status: 'Active',
    createdAt: _timestamp(fiveMonthsAgo),
  );

  // 2. Mary Johnson - Pending, fresh registration with no loans yet
  await _createBorrower(
    firstName: 'Mary',
    lastName: 'Johnson',
    nationalId: 'ID-$seedId-002',
    phone: '+254712345678',
    dateOfBirth: '1995-08-22',
    status: 'Pending',
    createdAt: _timestamp(today.subtract(const Duration(days: 2))),
  );

  // 3. Robert Williams - Active, has an overdue loan
  final robert = await _createBorrower(
    firstName: 'Robert',
    lastName: 'Williams',
    nationalId: 'ID-$seedId-003',
    phone: '+254723456789',
    dateOfBirth: '1988-11-03',
    status: 'Active',
    createdAt: _timestamp(fourMonthsAgo),
  );

  // 4. Patricia Brown - Active, has a fully paid-off loan
  final patricia = await _createBorrower(
    firstName: 'Patricia',
    lastName: 'Brown',
    nationalId: 'ID-$seedId-004',
    phone: '+254734567890',
    dateOfBirth: '1992-04-10',
    status: 'Active',
    createdAt: _timestamp(fiveMonthsAgo),
  );

  // 5. James Miller - Active, overdue with penalty
  final james = await _createBorrower(
    firstName: 'James',
    lastName: 'Miller',
    nationalId: 'ID-$seedId-005',
    phone: '+254745678901',
    dateOfBirth: '1985-07-30',
    status: 'Active',
    createdAt: _timestamp(fiveMonthsAgo),
  );

  print('\n=== Creating loans... ===');

  // John's Loan - Active, 50,000, 10%/mo, 6 months
  final johnLoan = await _createLoan(
    borrowerId: john,
    originalPrincipal: '50000.00',
    monthlyRate: '10',
    termMonths: 6,
    paymentsPerMonth: 1,
    startDate: _date(fiveMonthsAgo),
    firstDueDate: _date(fourMonthsAgo),
  );

  // John's 2nd Loan - Active, recently created
  await _createLoan(
    borrowerId: john,
    originalPrincipal: '30000.00',
    monthlyRate: '8',
    termMonths: 3,
    paymentsPerMonth: 1,
    startDate: _date(oneMonthAgo),
    firstDueDate: _date(thisMonth),
  );

  // Robert's Loan - Overdue, 25,000
  final robertLoan = await _createLoan(
    borrowerId: robert,
    originalPrincipal: '25000.00',
    monthlyRate: '12',
    termMonths: 4,
    paymentsPerMonth: 1,
    startDate: _date(fourMonthsAgo),
    firstDueDate: _date(threeMonthsAgo),
  );

  // Patricia's Loan - Paid off
  final patriciaLoan = await _createLoan(
    borrowerId: patricia,
    originalPrincipal: '20000.00',
    monthlyRate: '10',
    termMonths: 3,
    paymentsPerMonth: 1,
    startDate: _date(fiveMonthsAgo),
    firstDueDate: _date(fourMonthsAgo),
  );

  // James's Loan - Overdue, 40,000, 15%/mo
  final jamesLoan = await _createLoan(
    borrowerId: james,
    originalPrincipal: '40000.00',
    monthlyRate: '15',
    termMonths: 5,
    paymentsPerMonth: 1,
    startDate: _date(fiveMonthsAgo),
    firstDueDate: _date(fourMonthsAgo),
  );

  print('\n=== Recording payments... ===');

  // John's Loan - several on-time payments
  await _recordPayment(
    loanId: johnLoan,
    amount: '11000.00',
    effectiveDate: _date(fourMonthsAgo),
    note: 'First installment payment',
  );
  await _recordPayment(
    loanId: johnLoan,
    amount: '11000.00',
    effectiveDate: _date(threeMonthsAgo),
    note: 'Second installment',
  );
  // Third payment
  await _recordPayment(
    loanId: johnLoan,
    amount: '11000.00',
    effectiveDate: _date(twoMonthsAgo),
    note: 'Third installment',
  );
  // Fourth payment - will be reversed to demonstrate
  final fourthPaymentId = await _recordPaymentRaw(
    loanId: johnLoan,
    amount: '11000.00',
    effectiveDate: _date(oneMonthAgo),
    note: 'Fourth installment',
  );

  // Reverse John's fourth (latest) payment
  await _reversePayment(
    loanId: johnLoan,
    paymentId: fourthPaymentId,
    effectiveDate: _date(oneMonthAgo.add(const Duration(days: 9))),
    reason: 'Customer overpaid - reversed to correct balance',
  );

  // Patricia's Loan - fully paid off in one go
  await _recordPayment(
    loanId: patriciaLoan,
    amount: '25000.00',
    effectiveDate: _date(fiveMonthsAgo.add(const Duration(days: 10))),
    note: 'Full payoff - early settlement',
  );

  // James's Loan - one late payment, rest missed (overdue)
  await _recordPayment(
    loanId: jamesLoan,
    amount: '12000.00',
    effectiveDate: _date(fourMonthsAgo.add(const Duration(days: 9))),
    note: 'Late first payment (9 days overdue)',
  );

  print('\n=== Setting Overdue, Paid, and Due Today statuses... ===');
  await _updateLoanStatus(loanId: robertLoan, status: 'Overdue');
  await _updateLoanStatus(loanId: jamesLoan, status: 'Overdue');
  await _updateLoanStatus(loanId: patriciaLoan, status: 'Paid');
  await _updateLoanStatus(loanId: johnLoan, status: 'Active', dueToday: true);

  print('\n=== Seed complete! ===');
  print('');
  print('Summary:');
  print('- 5 borrowers created (4 Active, 1 Pending)');
  print('- 5 loans created across Active, Overdue, and Paid scenarios');
  print('- 1 loan installment set due today for Today\'s Collections');
  print('- 6 payments recorded and 1 payment reversed');
}

Future<void> _updateLoanStatus({
  required String loanId,
  required String status,
  bool dueToday = false,
}) async {
  await _dio.post<void>(
    '/api/v1/admin/loans/$loanId/status',
    data: {
      'status': status,
      'dueToday': dueToday,
    },
  );
  print('Updated loan $loanId status to: $status (dueToday: $dueToday)');
}

Future<String> _recordPaymentRaw({
  required String loanId,
  required String amount,
  required String effectiveDate,
  String? note,
}) async {
  final requestId = _uuid.v4();
  final response = await _dio.post<Map<String, dynamic>>(
    '/api/v1/loans/$loanId/payments',
    data: {
      'requestId': requestId,
      'amount': amount,
      'effectiveDate': effectiveDate,
      if (note != null && note.isNotEmpty) 'note': note,
    },
  );
  final paymentId = response.data!['id'] as String;
  print('Recorded payment $paymentId: $amount on $effectiveDate');
  return paymentId;
}
