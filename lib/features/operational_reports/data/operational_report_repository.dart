import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/formatters.dart';

/// Loads reproducible backend-calculated operational reports.
class OperationalReportRepository {
  const OperationalReportRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> portfolioRisk(DateTime asOf) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.portfolioRiskReport,
      queryParameters: {'asOf': formatDateOnly(asOf)},
    );
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> collectorReconciliation({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.collectorReconciliationReport,
      queryParameters: {
        'dateFrom': formatDateOnly(dateFrom),
        'dateTo': formatDateOnly(dateTo),
      },
    );
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> trialBalance(DateTime asOf) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.accountingTrialBalance,
      queryParameters: {'as_of': asOf.toUtc().toIso8601String()},
    );
    return response.data ?? const {};
  }
}

final operationalReportRepositoryProvider =
    Provider<OperationalReportRepository>((ref) {
      return OperationalReportRepository(ref.watch(apiClientProvider));
    });
