import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/local_json_cache.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/offline_sync_service.dart';

/// Encapsulates authenticated collection-task API operations.
class CollectionTaskRepository {
  const CollectionTaskRepository(this._dio, this._sync, this._cache);

  final Dio _dio;
  final OfflineSyncService _sync;
  final LocalJsonCache _cache;
  static const _tasksKey = 'collection-tasks';
  static const _completedKey = 'collection-tasks:completed';

  Future<List<Map<String, dynamic>>> list() async {
    final cached = await _cache.read(_tasksKey);
    unawaited(_refreshTasks());
    return (cached is List ? cached : const <dynamic>[])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<Set<String>> completedInstallments() async {
    final cached = await _cache.read(_completedKey);
    unawaited(_refreshCompleted());
    return (cached is List ? cached : const <dynamic>[])
        .map((value) => '$value')
        .toSet();
  }

  Future<void> _refreshTasks() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.collectionTasks,
      );
      await _cache.write(_tasksKey, response.data ?? const <dynamic>[]);
    } catch (_) {}
  }

  Future<void> _refreshCompleted() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.completedCollectionTasks,
      );
      await _cache.write(_completedKey, response.data ?? const <dynamic>[]);
    } catch (_) {}
  }

  Future<void> create(Map<String, dynamic> payload) async {
    final fingerprint = sha256.convert(utf8.encode(jsonEncode(payload)));
    final cached = await _cache.read(_tasksKey);
    final tasks = cached is List ? List<dynamic>.from(cached) : <dynamic>[];
    tasks.insert(0, {...payload, 'id': const Uuid().v4(), 'status': 'Pending'});
    await _cache.write(_tasksKey, tasks);
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
    unawaited(_sync.drainQueue());
  }

  Future<void> completeScheduled(String taskId) async {
    final endpoint = ApiEndpoints.completeScheduledCollectionTask(taskId);
    await _updateCachedTask(taskId, {'status': 'Completed'});
    await _sync.enqueue(
      endpoint: endpoint,
      method: 'POST',
      payload: const {},
      entityType: 'collection_task',
      entityLocalId: taskId,
      operationType: 'complete',
    );
    unawaited(_sync.drainQueue());
  }

  Future<void> completeInstallment(String loanId, int installmentNumber) async {
    final endpoint = ApiEndpoints.completeCollectionTask(
      loanId,
      installmentNumber,
    );
    final cached = await _cache.read(_completedKey);
    final completed = cached is List
        ? cached.map((value) => '$value').toSet()
        : <String>{};
    completed.add('${loanId}_$installmentNumber');
    await _cache.write(_completedKey, completed.toList());
    await _sync.enqueue(
      endpoint: endpoint,
      method: 'POST',
      payload: const {},
      entityType: 'collection_task',
      entityLocalId: '${loanId}_$installmentNumber',
      operationType: 'complete',
      dependencyIds: [loanId],
    );
    unawaited(_sync.drainQueue());
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
    await _updateCachedTask(taskId, payload);
    await _sync.enqueue(
      endpoint: endpoint,
      method: 'PATCH',
      payload: payload,
      entityType: 'promise_to_pay',
      entityLocalId: taskId,
      operationType: 'status',
      dependencyIds: [?linkedPaymentId],
    );
    unawaited(_sync.drainQueue());
  }

  Future<void> _updateCachedTask(
    String taskId,
    Map<String, dynamic> changes,
  ) async {
    final cached = await _cache.read(_tasksKey);
    if (cached is! List) return;
    final tasks = cached.map((item) {
      final task = Map<String, dynamic>.from(item as Map);
      if (task['id'] == taskId) task.addAll(changes);
      return task;
    }).toList();
    await _cache.write(_tasksKey, tasks);
  }
}

final collectionTaskRepositoryProvider = Provider<CollectionTaskRepository>((
  ref,
) {
  return CollectionTaskRepository(
    ref.watch(apiClientProvider),
    ref.watch(offlineSyncServiceProvider),
    ref.watch(localJsonCacheProvider),
  );
});
