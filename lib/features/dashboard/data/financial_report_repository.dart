import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/financial_report.dart';

/// Loads authenticated database-backed financial report projections.
class FinancialReportRepository {
  const FinancialReportRepository(this._dio);

  final Dio _dio;

  Future<FinancialReport> load({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.financialReport,
      queryParameters: {'dateFrom': _date(dateFrom), 'dateTo': _date(dateTo)},
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Financial report response was empty');
    }
    return FinancialReport.fromJson(data);
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

final financialReportRepositoryProvider = Provider<FinancialReportRepository>((
  ref,
) {
  return FinancialReportRepository(ref.watch(apiClientProvider));
});
