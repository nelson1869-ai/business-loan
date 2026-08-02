import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/collection_session.dart';

/// Online-only access to cash-session reconciliation transitions.
class CollectionSessionRepository {
  const CollectionSessionRepository(this._dio);

  final Dio _dio;

  Future<List<CollectionSession>> list() async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.collectionSessions,
    );
    return (response.data ?? const [])
        .map(
          (item) => CollectionSession.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<CollectionSession> open({
    required String collectorUserId,
    required String openingCash,
  }) => _post(ApiEndpoints.collectionSessions, {
    'collectorUserId': collectorUserId,
    'openingCash': openingCash,
  });

  Future<CollectionSession> submit({
    required String id,
    required String actualCash,
    String? varianceReason,
  }) => _post(ApiEndpoints.collectionSessionAction(id, 'submit'), {
    'actualCash': actualCash,
    'varianceReason': varianceReason,
  });

  Future<CollectionSession> review(String id, String reason) =>
      _decision(id, 'review', reason);

  Future<CollectionSession> reconcile(String id, String reason) =>
      _decision(id, 'reconcile', reason);

  Future<CollectionSession> close(String id, String reason) =>
      _decision(id, 'close', reason);

  Future<CollectionSession> deposit({
    required String id,
    required String amount,
    required String reference,
  }) => _post(ApiEndpoints.collectionSessionAction(id, 'deposit'), {
    'amount': amount,
    'reference': reference,
  });

  Future<CollectionSession> _decision(
    String id,
    String action,
    String reason,
  ) => _post(ApiEndpoints.collectionSessionAction(id, action), {
    'reason': reason,
  });

  Future<CollectionSession> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: payload);
    return CollectionSession.fromJson(response.data!);
  }
}

final collectionSessionRepositoryProvider =
    Provider<CollectionSessionRepository>((ref) {
      return CollectionSessionRepository(ref.watch(apiClientProvider));
    });
