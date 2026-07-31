import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/core/database/local_json_cache.dart';
import 'package:lending_nelson/core/security/encryption_service.dart';
import 'package:lending_nelson/features/dashboard/data/financial_report_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

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

  test(
    'builds an uncached report from offline loans and pending payments',
    () async {
      final databaseService = DatabaseService(dbPath: inMemoryDatabasePath);
      addTearDown(databaseService.close);
      final db = await databaseService.database;
      await db.insert('borrowers', {
        'id': 'borrower-1',
        'first_name': 'Test',
        'last_name': 'Borrower',
        'national_id': 'enc_id',
        'phone': 'enc_phone',
        'date_of_birth': '1990-01-01',
        'status': 'Active',
        'created_at': '2026-01-01T00:00:00Z',
      });
      await db.insert('loans', {
        'id': 'loan-1',
        'borrower_id': 'borrower-1',
        'original_principal': '1000.00',
        'outstanding_principal': '850.00',
        'monthly_rate': '0.05',
        'term_months': 12,
        'payments_per_month': 1,
        'start_date': '2026-01-01',
        'first_due_date': '2026-02-01',
        'final_due_date': '2026-06-01',
        'status': 'Active',
        'created_at': '2026-01-01T00:00:00Z',
        'sync_status': 'pending',
        'data_json': jsonEncode({'unappliedCredit': '5.00'}),
      });
      await db.insert('repayments', {
        'id': 'payment-1',
        'loan_id': 'loan-1',
        'entry_type': 'Payment',
        'request_id': 'request-1',
        'amount': '200.00',
        'effective_date': '2026-07-15',
        'allocation_json': jsonEncode({
          'allocation': {
            'appliedInterest': '50.00',
            'appliedPrincipal': '150.00',
          },
        }),
        'created_at': '2026-07-15T10:00:00Z',
        'sync_status': 'pending',
      });

      final repository = FinancialReportRepository(
        Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1')),
        LocalJsonCache(databaseService, _TestEncryptionService()),
        databaseService,
      );
      final report = await repository.load(
        dateFrom: DateTime(2026, 7, 1),
        dateTo: DateTime(2026, 7, 31),
      );

      expect(report.collections, '200.00');
      expect(report.interestEarned, '50.00');
      expect(report.principalCollected, '150.00');
      expect(report.outstandingPortfolio, '850.00');
      expect(report.unappliedCredits, '5.00');
      expect(report.overdueAmount, '850.00');
      expect(report.collectorPerformance['Offline collections'], '200.00');
    },
  );
}

class _TestEncryptionService extends EncryptionService {
  _TestEncryptionService() : super(const FlutterSecureStorage());

  @override
  Future<String> encrypt(String plainText) async => plainText;

  @override
  Future<String> decrypt(String cipherTextWithIv) async => cipherTextWithIv;
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
