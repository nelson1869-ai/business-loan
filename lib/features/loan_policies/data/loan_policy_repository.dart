import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/loan_policy.dart';

/// Online-only access to backend-owned loan policy versions.
class LoanPolicyRepository {
  const LoanPolicyRepository(this._dio);

  final Dio _dio;

  Future<List<LoanPolicy>> list() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.loanPolicies);
    return (response.data ?? const [])
        .map(
          (item) => LoanPolicy.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<LoanPolicy> createDraft(Map<String, dynamic> payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.loanPolicies,
      data: payload,
    );
    return LoanPolicy.fromJson(response.data!);
  }

  Future<LoanPolicy> activate(String id, String reason) =>
      _decision(ApiEndpoints.activateLoanPolicy(id), reason);

  Future<LoanPolicy> retire(String id, String reason) =>
      _decision(ApiEndpoints.retireLoanPolicy(id), reason);

  Future<LoanPolicy> _decision(String path, String reason) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: {'reason': reason},
    );
    return LoanPolicy.fromJson(response.data!);
  }
}

final loanPolicyRepositoryProvider = Provider<LoanPolicyRepository>((ref) {
  return LoanPolicyRepository(ref.watch(apiClientProvider));
});
