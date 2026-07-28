import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/local_json_cache.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/financial_report.dart';

/// Loads authenticated database-backed financial report projections.
class FinancialReportRepository {
  const FinancialReportRepository(this._dio, [this._cache, this._database]);

  final Dio _dio;
  final LocalJsonCache? _cache;
  final DatabaseService? _database;

  Future<FinancialReport> load({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final key = 'financial-report:${_date(dateFrom)}:${_date(dateTo)}';
    final cache = _cache;
    if (cache == null) {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.financialReport,
        queryParameters: {'dateFrom': _date(dateFrom), 'dateTo': _date(dateTo)},
      );
      return FinancialReport.fromJson(response.data ?? const {});
    }
    final cached = await cache.read(key);
    unawaited(_refresh(key, dateFrom, dateTo));
    final hasPendingChanges = await _hasPendingLocalChanges();
    if (cached is Map && !hasPendingChanges) {
      return FinancialReport.fromJson(Map<String, dynamic>.from(cached));
    }
    final local = await _loadLocal(dateFrom, dateTo);
    if (local != null) return local;
    if (cached is Map) {
      return FinancialReport.fromJson(Map<String, dynamic>.from(cached));
    }
    throw StateError('This report has not been cached for offline use.');
  }

  Future<bool> _hasPendingLocalChanges() async {
    final databaseService = _database;
    if (databaseService == null) return false;
    final db = await databaseService.database;
    for (final table in ['loans', 'repayments']) {
      final rows = await db.rawQuery(
        "SELECT 1 FROM $table WHERE sync_status != 'synced' LIMIT 1",
      );
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  /// Builds the report from the same local loans and immutable repayment
  /// ledger used by offline collection. Pending payments are therefore visible
  /// immediately, before queue replay reaches the server.
  Future<FinancialReport?> _loadLocal(
    DateTime dateFrom,
    DateTime dateTo,
  ) async {
    final databaseService = _database;
    if (databaseService == null) return null;
    final db = await databaseService.database;
    final loans = await db.query('loans', where: 'deleted_at IS NULL');
    if (loans.isEmpty) return null;

    final from = _date(dateFrom);
    final to = _date(dateTo);
    final repayments = await db.query(
      'repayments',
      where: 'effective_date >= ? AND effective_date <= ?',
      whereArgs: [from, to],
    );

    final reversalRows = await db.query(
      'repayments',
      columns: ['reversal_of_payment_id'],
      where: "entry_type = 'Reversal'",
    );
    final reversedPaymentIds = reversalRows
        .map((row) => row['reversal_of_payment_id']?.toString())
        .whereType<String>()
        .toSet();

    var collections = 0;
    var interestEarned = 0;
    var principalCollected = 0;
    for (final row in repayments) {
      if (row['entry_type'] == 'Reversal' ||
          reversedPaymentIds.contains(row['id']?.toString())) {
        continue;
      }
      collections += _cents(row['amount']);
      final allocation = _jsonMap(row['allocation_json']);
      final values = _jsonMap(allocation['allocation']);
      interestEarned += _cents(values['appliedInterest']);
      principalCollected += _cents(values['appliedPrincipal']);
    }

    var outstanding = 0;
    var unappliedCredits = 0;
    var overdueAmount = 0;
    var overdueCount = 0;
    final aging = <String, int>{
      'current': 0,
      '1-30': 0,
      '31-60': 0,
      '61-90': 0,
      '91+': 0,
    };
    final asOf = DateTime(dateTo.year, dateTo.month, dateTo.day);

    for (final loan in loans) {
      final balance = _cents(loan['outstanding_principal']);
      final status = loan['status']?.toString() ?? 'Active';
      if (status != 'Paid' && status != 'Cancelled') outstanding += balance;

      final data = _jsonMap(loan['data_json']);
      unappliedCredits += _cents(data['unappliedCredit']);

      final dueText = loan['final_due_date']?.toString() ?? '';
      final due = DateTime.tryParse(dueText);
      final daysOverdue = due == null ? 0 : asOf.difference(due).inDays;
      final bucket = daysOverdue <= 0
          ? 'current'
          : daysOverdue <= 30
          ? '1-30'
          : daysOverdue <= 60
          ? '31-60'
          : daysOverdue <= 90
          ? '61-90'
          : '91+';
      aging[bucket] = aging[bucket]! + balance;
      if (daysOverdue > 0 && balance > 0) {
        overdueAmount += balance;
        overdueCount++;
      }
    }

    final par = outstanding == 0 ? 0 : ((overdueAmount * 10000) ~/ outstanding);
    return FinancialReport(
      dateFrom: from,
      dateTo: to,
      outstandingPortfolio: _money(outstanding),
      collections: _money(collections),
      interestEarned: _money(interestEarned),
      principalCollected: _money(principalCollected),
      unappliedCredits: _money(unappliedCredits),
      overdueAmount: _money(overdueAmount),
      portfolioAtRisk: _money(par),
      overdueLoanCount: overdueCount,
      loanAging: aging.map((key, value) => MapEntry(key, _money(value))),
      collectorPerformance: {
        if (collections > 0) 'Offline collections': _money(collections),
      },
    );
  }

  Future<void> _refresh(String key, DateTime dateFrom, DateTime dateTo) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.financialReport,
        queryParameters: {'dateFrom': _date(dateFrom), 'dateTo': _date(dateTo)},
      );
      if (response.data != null) await _cache?.write(key, response.data);
    } catch (_) {}
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _jsonMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is! String || value.isEmpty) return const {};
    try {
      return Map<String, dynamic>.from(jsonDecode(value) as Map);
    } catch (_) {
      return const {};
    }
  }

  int _cents(Object? value) =>
      ((double.tryParse(value?.toString() ?? '') ?? 0) * 100).round();

  String _money(int cents) => (cents / 100).toStringAsFixed(2);
}

final financialReportRepositoryProvider = Provider<FinancialReportRepository>((
  ref,
) {
  return FinancialReportRepository(
    ref.watch(apiClientProvider),
    ref.watch(localJsonCacheProvider),
    ref.watch(databaseServiceProvider),
  );
});
