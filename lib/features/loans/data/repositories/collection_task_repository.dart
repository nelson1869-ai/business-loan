import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

/// Encapsulates authenticated collection-task API operations.
class CollectionTaskRepository {
  const CollectionTaskRepository(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> list() async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.collectionTasks,
    );
    return (response.data ?? const <dynamic>[])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<Set<String>> completedInstallments() async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.completedCollectionTasks,
    );
    return (response.data ?? const <dynamic>[])
        .map((value) => '$value')
        .toSet();
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await _dio.post<void>(ApiEndpoints.collectionTasks, data: payload);
  }

  Future<void> completeScheduled(String taskId) async {
    await _dio.post<void>(
      ApiEndpoints.completeScheduledCollectionTask(taskId),
      data: const <String, dynamic>{},
    );
  }

  Future<void> completeInstallment(String loanId, int installmentNumber) async {
    await _dio.post<void>(
      ApiEndpoints.completeCollectionTask(loanId, installmentNumber),
    );
  }
}

final collectionTaskRepositoryProvider = Provider<CollectionTaskRepository>((
  ref,
) {
  return CollectionTaskRepository(ref.watch(apiClientProvider));
});
