import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/loans/data/models/loan_create_request.dart';
import 'package:lending_nelson/features/loans/data/repositories/remote_loan_repository.dart';

void main() {
  late Dio dio;
  late _RecordingAdapter adapter;
  late RemoteLoanRepository repository;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'))
      ..httpClientAdapter = adapter;
    repository = RemoteLoanRepository(dio);
  });

  test('create sends exact terms and parses the returned schedule', () async {
    adapter.responseData = _loanJson(includeInstallments: true);
    const request = LoanCreateRequest(
      borrowerId: 'borrower-1',
      requestId: '00000000-0000-4000-8000-000000000002',
      originalPrincipal: '1000.00',
      monthlyRate: '0.10',
      termMonths: 5,
      paymentsPerMonth: 2,
      startDate: '2026-08-01',
      firstDueDate: '2026-08-05',
    );

    final loan = await repository.createLoan(request);

    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.path, '/api/v1/loans');
    expect(adapter.lastRequest?.data, request.toJson());
    expect(adapter.lastRequest?.data['monthlyRate'], isA<String>());
    expect(loan.installments, hasLength(1));
  });

  test('draft creation uses the controlled workflow endpoint', () async {
    adapter.responseData = _loanJson(includeInstallments: true);
    const request = LoanCreateRequest(
      borrowerId: 'borrower-1',
      requestId: '00000000-0000-4000-8000-000000000002',
      originalPrincipal: '1000.00',
      monthlyRate: '0.10',
      termMonths: 5,
      paymentsPerMonth: 2,
      startDate: '2026-08-01',
      firstDueDate: '2026-08-05',
    );

    await repository.createDraft(request);

    expect(adapter.lastRequest?.path, '/api/v1/loans/drafts');
    expect(adapter.lastRequest?.data, request.toJson());
  });

  test('workflow transition uses the existing action endpoint', () async {
    adapter.responseData = _loanJson(includeInstallments: true)
      ..['approvedAt'] = '2026-08-02T10:00:00Z';

    final loan = await repository.transition('loan-1', 'approve');

    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.path, '/api/v1/loans/loan-1/workflow/approve');
    expect(loan.approvedAt, '2026-08-02T10:00:00Z');
  });

  test('workflow transition fetches full loan when backend returns LoanWorkflowResponse', () async {
    // When backend returns LoanWorkflowResponse (minimal envelope)
    final workflowResponse = <String, dynamic>{
      'loanId': 'loan-1',
      'action': 'approve_and_activate',
      'status': 'Active',
      'occurredAt': '2026-08-06T12:00:00Z',
    };
    final fullLoanJson = _loanJson(includeInstallments: true);

    adapter.customFetchHandler = (options) {
      if (options.method == 'POST' && options.path.contains('/workflow/')) {
        return workflowResponse;
      }
      return fullLoanJson;
    };

    final loan = await repository.transition('loan-1', 'approve_and_activate');

    expect(loan.id, 'loan-1');
    expect(loan.status, 'Active');
  });

  test('list sends borrower filter and parses loan summaries', () async {
    adapter.responseData = <Map<String, dynamic>>[
      _loanJson(includeInstallments: false),
    ];

    final loans = await repository.getLoans(
      borrowerId: 'borrower-1',
      status: 'Active',
    );

    expect(adapter.lastRequest?.method, 'GET');
    expect(adapter.lastRequest?.queryParameters, <String, dynamic>{
      'borrowerId': 'borrower-1',
      'status': 'Active',
    });
    expect(loans.single.installments, isEmpty);
  });

  test('detail uses the loan id and returns installments', () async {
    adapter.responseData = _loanJson(includeInstallments: true);

    final loan = await repository.getLoan('loan-1');

    expect(adapter.lastRequest?.path, '/api/v1/loans/loan-1');
    expect(loan.id, 'loan-1');
    expect(loan.installments.single.installmentNumber, 1);
  });

  test(
    'explanation sends only the loan id and parses structured output',
    () async {
      adapter.responseData = <String, dynamic>{
        'summary': 'This loan has ten scheduled payments.',
        'keyPoints': <String>['The regular payment is \$129.50.'],
        'generatedAt': '2026-07-28T12:00:00Z',
        'model': 'openai/gpt-oss-20b',
        'disclaimer': 'AI-generated explanation.',
      };

      final explanation = await repository.explainLoan('loan-1');

      expect(adapter.lastRequest?.method, 'POST');
      expect(adapter.lastRequest?.path, '/api/v1/loans/loan-1/explanation');
      expect(adapter.lastRequest?.data, isNull);
      expect(explanation.keyPoints, hasLength(1));
      expect(explanation.model, 'openai/gpt-oss-20b');
    },
  );

  test('backend detail is exposed as a non-retryable exception', () async {
    adapter
      ..statusCode = 422
      ..responseData = <String, dynamic>{
        'detail': <Map<String, dynamic>>[
          <String, dynamic>{
            'loc': <String>['body', 'firstDueDate'],
            'msg': 'must be after startDate',
          },
        ],
      };

    expect(
      () => repository.createLoan(
        const LoanCreateRequest(
          borrowerId: 'borrower-1',
          requestId: '00000000-0000-4000-8000-000000000002',
          originalPrincipal: '1000.00',
          monthlyRate: '0.10',
          termMonths: 5,
          paymentsPerMonth: 2,
          startDate: '2026-08-01',
          firstDueDate: '2026-08-01',
        ),
      ),
      throwsA(
        isA<RemoteLoanException>()
            .having((error) => error.statusCode, 'statusCode', 422)
            .having((error) => error.isRetryable, 'isRetryable', false)
            .having(
              (error) => error.message,
              'message',
              'firstDueDate: must be after startDate',
            ),
      ),
    );
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  Object? responseData;
  Object? Function(RequestOptions options)? customFetchHandler;
  int statusCode = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final data = customFetchHandler != null
        ? customFetchHandler!(options)
        : responseData;
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _loanJson({required bool includeInstallments}) {
  final loan = <String, dynamic>{
    'id': 'loan-1',
    'requestId': '00000000-0000-4000-8000-000000000002',
    'borrowerId': 'borrower-1',
    'createdByUserId': 'user-1',
    'originalPrincipal': '1000.00',
    'outstandingPrincipal': '1000.00',
    'monthlyRate': '0.10000000',
    'termMonths': 5,
    'paymentsPerMonth': 2,
    'numberOfPayments': 10,
    'regularPaymentAmount': '129.50',
    'calculationMethod': 'fixed_periodic_reducing_balance',
    'startDate': '2026-08-01',
    'firstDueDate': '2026-08-05',
    'finalDueDate': '2026-12-20',
    'status': 'Active',
    'createdAt': '2026-08-01T00:00:00Z',
  };
  if (includeInstallments) {
    loan['installments'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'installment-1',
        'loanId': 'loan-1',
        'installmentNumber': 1,
        'dueDate': '2026-08-05',
        'expectedPayment': '129.50',
        'expectedInterest': '50.00',
        'expectedPrincipal': '79.50',
        'expectedRemainingPrincipal': '920.50',
        'paidAmount': '0.00',
        'status': 'Scheduled',
        'createdAt': '2026-08-01T00:00:00Z',
      },
    ];
  }
  return loan;
}
