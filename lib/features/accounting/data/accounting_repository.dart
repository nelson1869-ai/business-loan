import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/journal_entry.dart';

/// Read-only access to immutable backend accounting journals.
class AccountingRepository {
  const AccountingRepository(this._dio);

  final Dio _dio;

  Future<List<JournalEntry>> listJournals({int offset = 0}) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.accountingJournals,
      queryParameters: {'offset': offset, 'limit': 100},
    );
    return (response.data ?? const [])
        .map(
          (item) =>
              JournalEntry.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> trialBalance(DateTime asOf) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.accountingTrialBalance,
      queryParameters: {'as_of': asOf.toUtc().toIso8601String()},
    );
    return response.data ?? const {};
  }
}

final accountingRepositoryProvider = Provider<AccountingRepository>((ref) {
  return AccountingRepository(ref.watch(apiClientProvider));
});
