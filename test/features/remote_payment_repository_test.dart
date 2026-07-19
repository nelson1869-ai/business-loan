import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/loans/data/repositories/remote_payment_repository.dart';

void main() {
  late _PaymentAdapter adapter;
  late RemotePaymentRepository repository;

  setUp(() {
    adapter = _PaymentAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'))
      ..httpClientAdapter = adapter;
    repository = RemotePaymentRepository(dio);
  });

  test(
    'preview sends exact strings and parses authoritative allocation',
    () async {
      adapter.responseData = _previewJson();

      final preview = await repository.preview(
        loanId: 'loan-1',
        amount: '200.00',
        effectiveDate: '2026-08-16',
      );

      expect(
        adapter.lastRequest?.path,
        '/api/v1/loans/loan-1/payments/preview',
      );
      expect(adapter.lastRequest?.data, <String, dynamic>{
        'amount': '200.00',
        'effectiveDate': '2026-08-16',
      });
      expect(preview.appliedInterest, '50.00');
      expect(preview.appliedPrincipal, '150.00');
      expect(preview.principalAfter, '850.00');
    },
  );

  test(
    'confirmation sends retry UUID and parses immutable allocation',
    () async {
      adapter.responseData = _paymentJson();

      final payment = await repository.confirm(
        loanId: 'loan-1',
        requestId: '00000000-0000-4000-8000-000000000099',
        amount: '200.00',
        effectiveDate: '2026-08-16',
        note: ' First collection ',
      );

      expect(adapter.lastRequest?.path, '/api/v1/loans/loan-1/payments');
      expect(
        adapter.lastRequest?.data['requestId'],
        '00000000-0000-4000-8000-000000000099',
      );
      expect(adapter.lastRequest?.data['amount'], isA<String>());
      expect(adapter.lastRequest?.data['note'], 'First collection');
      expect(payment.allocation.principalAfter, '850.00');
    },
  );

  test('history parses allocation snapshots', () async {
    adapter.responseData = <Map<String, dynamic>>[_paymentJson()];

    final payments = await repository.history('loan-1');

    expect(adapter.lastRequest?.method, 'GET');
    expect(payments.single.amount, '200.00');
    expect(payments.single.allocation.appliedPrincipal, '150.00');
  });
}

class _PaymentAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  Object? responseData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(responseData),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _previewJson() => <String, dynamic>{
  'loanId': 'loan-1',
  'installmentId': 'installment-1',
  'paymentAmount': '200.00',
  'effectiveDate': '2026-08-16',
  'periodStartDate': '2026-08-01',
  'accrualStartDate': '2026-08-01',
  'dueDate': '2026-08-16',
  'scheduledPeriodDays': 15,
  'elapsedDays': 15,
  'daysEarly': 0,
  'overdueDays': 0,
  'periodicRate': '0.05000000',
  'accruedInterest': '50.00',
  'carriedInterestBefore': '0.00',
  'totalInterestBefore': '50.00',
  'principalBefore': '1000.00',
  'appliedInterest': '50.00',
  'appliedPrincipal': '150.00',
  'unappliedCredit': '0.00',
  'interestAfter': '0.00',
  'principalAfter': '850.00',
  'scheduledPayment': '129.50',
  'amountAboveScheduled': '70.50',
  'nextPeriodInterest': '42.50',
  'isPayoff': false,
};

Map<String, dynamic> _paymentJson() => <String, dynamic>{
  'id': 'payment-1',
  'requestId': '00000000-0000-4000-8000-000000000099',
  'loanId': 'loan-1',
  'installmentId': 'installment-1',
  'recordedByUserId': 'user-1',
  'entryType': 'Payment',
  'amount': '200.00',
  'effectiveDate': '2026-08-16',
  'note': 'First collection',
  'createdAt': '2026-08-16T10:00:00Z',
  'allocation': <String, dynamic>{
    'interestBefore': '50.00',
    'principalBefore': '1000.00',
    'appliedInterest': '50.00',
    'appliedPrincipal': '150.00',
    'unappliedCredit': '0.00',
    'interestAfter': '0.00',
    'principalAfter': '850.00',
    'overdueDays': 0,
    'scheduledPeriodDays': 15,
  },
};
