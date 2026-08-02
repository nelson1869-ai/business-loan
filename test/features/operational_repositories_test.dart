import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/accounting/data/accounting_repository.dart';
import 'package:lending_nelson/features/approvals/data/approval_repository.dart';
import 'package:lending_nelson/features/collection_sessions/data/collection_session_repository.dart';
import 'package:lending_nelson/features/loan_policies/data/loan_policy_repository.dart';
import 'package:lending_nelson/features/operational_reports/data/operational_report_repository.dart';

void main() {
  late Dio dio;
  late _Adapter adapter;

  setUp(() {
    adapter = _Adapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = adapter;
  });

  test('policy activation is an online POST with a reason', () async {
    adapter.responseData = _policyJson(status: 'active');
    final policy = await LoanPolicyRepository(
      dio,
    ).activate('policy-1', 'Approved by checker');
    expect(
      adapter.lastRequest?.path,
      '/api/v1/loan-policies/policy-1/activate',
    );
    expect(adapter.lastRequest?.data, {'reason': 'Approved by checker'});
    expect(policy.status, 'active');
  });

  test('approval decision sends no offline request identifier', () async {
    adapter.responseData = _approvalJson();
    await ApprovalRepository(dio).decide(
      requestId: 'approval-1',
      decision: 'approved',
      reason: 'Independent review complete',
    );
    expect(adapter.lastRequest?.path, '/api/v1/approvals/approval-1/decision');
    expect(adapter.lastRequest?.data, {
      'decision': 'approved',
      'reason': 'Independent review complete',
    });
  });

  test('collection deposit uses backend actual cash unchanged', () async {
    adapter.responseData = _sessionJson(status: 'deposited');
    await CollectionSessionRepository(
      dio,
    ).deposit(id: 'session-1', amount: '1250.75', reference: 'BANK-42');
    expect(
      adapter.lastRequest?.path,
      '/api/v1/collection-sessions/session-1/deposit',
    );
    expect(adapter.lastRequest?.data, {
      'amount': '1250.75',
      'reference': 'BANK-42',
    });
  });

  test('accounting repository exposes immutable journal lines', () async {
    adapter.responseData = [_journalJson()];
    final journals = await AccountingRepository(dio).listJournals();
    expect(adapter.lastRequest?.method, 'GET');
    expect(journals.single.lines.single.debit, '100.00');
    expect(journals.single.status, 'posted');
  });

  test('portfolio report sends reproducible as-of date', () async {
    adapter.responseData = {'asOf': '2026-08-02', 'rows': <dynamic>[]};
    await OperationalReportRepository(dio).portfolioRisk(DateTime(2026, 8, 2));
    expect(adapter.lastRequest?.path, '/api/v1/reports/portfolio-risk');
    expect(adapter.lastRequest?.queryParameters, {'asOf': '2026-08-02'});
  });
}

class _Adapter implements HttpClientAdapter {
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
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _policyJson({required String status}) => {
  'id': 'policy-1',
  'policyName': 'Standard',
  'versionNumber': 1,
  'status': status,
  'currency': 'PHP',
  'minimumRate': '0.01',
  'maximumRate': '0.10',
  'interestMethod': 'fixed_periodic_reducing_balance',
  'ratePeriod': 'monthly',
  'effectiveDate': '2026-08-02',
  'changeReason': 'Initial version',
  'createdByUserId': 'maker-1',
  'approvedByUserId': 'checker-1',
  'createdAt': '2026-08-02T00:00:00Z',
};

Map<String, dynamic> _approvalJson() => {
  'id': 'approval-1',
  'action': 'loan.approve',
  'entityType': 'loan',
  'entityId': 'loan-1',
  'makerUserId': 'maker-1',
  'checkerUserId': 'checker-1',
  'status': 'approved',
  'requestReason': 'Approve loan',
  'decisionReason': 'Independent review complete',
  'createdAt': '2026-08-02T00:00:00Z',
  'decidedAt': '2026-08-02T01:00:00Z',
};

Map<String, dynamic> _sessionJson({required String status}) => {
  'id': 'session-1',
  'collectorUserId': 'collector-1',
  'openingCash': '0.00',
  'expectedCash': '1250.75',
  'actualCash': '1250.75',
  'cashVariance': '0.00',
  'varianceReason': null,
  'depositAmount': '1250.75',
  'depositReference': 'BANK-42',
  'status': status,
  'reviewerUserId': 'checker-1',
  'createdAt': '2026-08-02T00:00:00Z',
};

Map<String, dynamic> _journalJson() => {
  'id': 'journal-1',
  'currency': 'PHP',
  'postedAt': '2026-08-02T00:00:00Z',
  'sourceType': 'payment',
  'sourceRecordId': 'payment-1',
  'description': 'Payment receipt',
  'status': 'posted',
  'reconciliationStatus': 'unreconciled',
  'lines': [
    {
      'lineNumber': 1,
      'accountId': 'cash',
      'debit': '100.00',
      'credit': '0.00',
      'memo': 'Cash received',
    },
  ],
};
