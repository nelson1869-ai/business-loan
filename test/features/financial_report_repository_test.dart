import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/dashboard/data/financial_report_repository.dart';

void main() {
  test(
    'loads the database-backed financial projection with date filters',
    () async {
      final adapter = _ReportAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'))
        ..httpClientAdapter = adapter;
      final repository = FinancialReportRepository(dio);

      final report = await repository.load(
        dateFrom: DateTime(2026, 7, 1),
        dateTo: DateTime(2026, 7, 25),
      );

      expect(adapter.lastRequest?.path, '/api/v1/reports/financial');
      expect(adapter.lastRequest?.queryParameters, {
        'dateFrom': '2026-07-01',
        'dateTo': '2026-07-25',
      });
      expect(report.collections, '1250.00');
      expect(report.loanAging['31-60'], '350.00');
      expect(report.collectorPerformance['officer'], '1250.00');
    },
  );
}

class _ReportAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode({
        'dateFrom': '2026-07-01',
        'dateTo': '2026-07-25',
        'outstandingPortfolio': '5000.00',
        'collections': '1250.00',
        'interestEarned': '250.00',
        'principalCollected': '1000.00',
        'unappliedCredits': '0.00',
        'overdueAmount': '350.00',
        'portfolioAtRisk': '7.00',
        'overdueLoanCount': 1,
        'loanAging': {
          'current': '4650.00',
          '1-30': '0.00',
          '31-60': '350.00',
          '61-90': '0.00',
          '91+': '0.00',
        },
        'collectorPerformance': {'officer': '1250.00'},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
