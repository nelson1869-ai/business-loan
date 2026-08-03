import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/approval_request.dart';

/// Online-only maker-checker approval access.
class ApprovalRepository {
  const ApprovalRepository(this._dio);

  final Dio _dio;

  Future<List<ApprovalRequest>> list() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.approvals);
    return (response.data ?? const [])
        .map(
          (item) =>
              ApprovalRequest.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<ApprovalRequest> create({
    required String action,
    required String entityType,
    required String entityId,
    required String reason,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.approvals,
      data: {
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'reason': reason,
      },
    );
    return ApprovalRequest.fromJson(response.data!);
  }

  Future<ApprovalRequest> decide({
    required String requestId,
    required String decision,
    required String reason,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.approvalDecision(requestId),
      data: {'decision': decision, 'reason': reason},
    );
    return ApprovalRequest.fromJson(response.data!);
  }
}

final approvalRepositoryProvider = Provider<ApprovalRepository>((ref) {
  return ApprovalRepository(ref.watch(apiClientProvider));
});
