import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_json_cache.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/financial_report.dart';

/// Loads authenticated database-backed financial report projections.
class FinancialReportRepository {
  const FinancialReportRepository(this._dio, [this._cache]);

  final Dio _dio;
  final LocalJsonCache? _cache;

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
    if (cached is Map) {
      return FinancialReport.fromJson(Map<String, dynamic>.from(cached));
    }
    throw StateError('This report has not been cached for offline use.');
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
}

final financialReportRepositoryProvider = Provider<FinancialReportRepository>((
  ref,
) {
  return FinancialReportRepository(
    ref.watch(apiClientProvider),
    ref.watch(localJsonCacheProvider),
  );
});
