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
    try {
      final cached = await _cache.read(_cacheKey);
      final cachedItems = _parse(cached);
      if (cachedItems.isNotEmpty) {
        unawaited(_refresh());
        return cachedItems;
      }
    } catch (_) {
      // A stale or unreadable cache must never prevent the inbox from loading.
    }

    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.notifications,
      );
      final data = response.data ?? const <dynamic>[];
      await _cache.write(_cacheKey, data);
      return _parse(data);
    } catch (_) {
      // An empty offline inbox is a valid state. New alerts will load when the
      // connection returns and the user refreshes.
      return const <AppNotification>[];
    }
  }

  Future<void> _refresh() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.notifications,
      );
      await _cache.write(_cacheKey, response.data ?? const <dynamic>[]);
    } catch (_) {}
  }

  List<AppNotification> _parse(Object? value) {
    if (value is! List) return const <AppNotification>[];
    final result = <AppNotification>[];
    for (final item in value) {
      try {
        if (item is Map) {
          result.add(AppNotification.fromJson(Map<String, dynamic>.from(item)));
        }
      } catch (_) {
        // Skip only the malformed record and preserve the rest of the inbox.
      }
    }
    return List.unmodifiable(result);
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
