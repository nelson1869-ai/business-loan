import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_json_cache.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/offline_sync_service.dart';
import '../domain/app_notification.dart';

class NotificationRepository {
  const NotificationRepository(this._dio, this._sync, this._cache);

  final Dio _dio;
  final OfflineSyncService _sync;
  final LocalJsonCache _cache;
  static const _cacheKey = 'notifications';

  Future<List<AppNotification>> load() async {
    final cached = await _cache.read(_cacheKey);
    unawaited(_refresh());
    return (cached is List ? cached : const <dynamic>[])
        .map(
          (item) =>
              AppNotification.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<void> _refresh() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.notifications,
      );
      await _cache.write(_cacheKey, response.data ?? const <dynamic>[]);
    } catch (_) {}
  }

  Future<void> markRead(String notificationId) async {
    final endpoint = ApiEndpoints.markNotificationRead(notificationId);
    await _markLocally((row) => row['id'] == notificationId);
    await _sync.enqueue(
      endpoint: endpoint,
      method: 'POST',
      payload: const {},
      entityType: 'notification',
      entityLocalId: notificationId,
      operationType: 'markRead',
    );
    unawaited(_sync.drainQueue());
  }

  Future<void> markAllRead() async {
    await _markLocally((_) => true);
    await _sync.enqueue(
      endpoint: ApiEndpoints.markAllNotificationsRead,
      method: 'POST',
      payload: const {},
      entityType: 'notification',
      entityLocalId: 'all',
      operationType: 'markRead',
    );
    unawaited(_sync.drainQueue());
  }

  Future<void> _markLocally(bool Function(Map<String, dynamic>) matches) async {
    final cached = await _cache.read(_cacheKey);
    if (cached is! List) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = cached.map((item) {
      final row = Map<String, dynamic>.from(item as Map);
      if (matches(row)) row['readAt'] = now;
      return row;
    }).toList();
    await _cache.write(_cacheKey, rows);
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    ref.watch(apiClientProvider),
    ref.watch(offlineSyncServiceProvider),
    ref.watch(localJsonCacheProvider),
  );
});
