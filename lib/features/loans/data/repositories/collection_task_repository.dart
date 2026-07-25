import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/network/offline_sync_service.dart';

/// Encapsulates authenticated collection-task API operations.
class CollectionTaskRepository {
  const CollectionTaskRepository(this._dio, this._sync);

  final Dio _dio;
  final OfflineSyncService _sync;

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
    try {
      await _dio.post<void>(ApiEndpoints.collectionTasks, data: payload);
    } catch (error) {
      if (!ApiErrorMapper.isOfflineFailure(error)) rethrow;
      final fingerprint = sha256.convert(utf8.encode(jsonEncode(payload)));
      await _sync.enqueue(
        endpoint: ApiEndpoints.collectionTasks,
        method: 'POST',
        payload: payload,
        entityType: payload['taskType'] == 'PromiseToPay'
            ? 'promise_to_pay'
            : 'collection_task',
        entityLocalId: '$fingerprint',
        operationType: 'create',
        dependencyIds: ['${payload['borrowerId']}', '${payload['loanId']}'],
      );
    }
  }

  Future<void> completeScheduled(String taskId) async {
    final endpoint = ApiEndpoints.completeScheduledCollectionTask(taskId);
    try {
      await _dio.post<void>(endpoint, data: const <String, dynamic>{});
    } catch (error) {
      if (!ApiErrorMapper.isOfflineFailure(error)) rethrow;
      await _sync.enqueue(
        endpoint: endpoint,
        method: 'POST',
        payload: const {},
        entityType: 'collection_task',
        entityLocalId: taskId,
        operationType: 'complete',
      );
    }
  }

  Future<void> completeInstallment(String loanId, int installmentNumber) async {
    final endpoint = ApiEndpoints.completeCollectionTask(
      loanId,
      installmentNumber,
    );
    try {
      await _dio.post<void>(endpoint);
    } catch (error) {
      if (!ApiErrorMapper.isOfflineFailure(error)) rethrow;
      await _sync.enqueue(
        endpoint: endpoint,
        method: 'POST',
        payload: const {},
        entityType: 'collection_task',
        entityLocalId: '${loanId}_$installmentNumber',
        operationType: 'complete',
        dependencyIds: [loanId],
      );
    }
  }

  Future<void> updatePromiseStatus(
    String taskId, {
    required String status,
    String? linkedPaymentId,
  }) async {
    final endpoint = ApiEndpoints.collectionPromiseStatus(taskId);
    final payload = {
      'promiseStatus': status,
      'linkedPaymentId': ?linkedPaymentId,
    };
    try {
      await _dio.patch<void>(endpoint, data: payload);
    } catch (error) {
      if (!ApiErrorMapper.isOfflineFailure(error)) rethrow;
      await _sync.enqueue(
        endpoint: endpoint,
        method: 'PATCH',
        payload: payload,
        entityType: 'promise_to_pay',
        entityLocalId: taskId,
        operationType: 'status',
        dependencyIds: [?linkedPaymentId],
      );
    }
  }
}

final collectionTaskRepositoryProvider = Provider<CollectionTaskRepository>((
  ref,
) {
  return CollectionTaskRepository(
    ref.watch(apiClientProvider),
    ref.watch(offlineSyncServiceProvider),
  );
});
