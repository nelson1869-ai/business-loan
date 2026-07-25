import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/network/offline_sync_service.dart';
import '../domain/app_notification.dart';

class NotificationRepository {
  const NotificationRepository(this._dio, this._sync);

  final Dio _dio;
  final OfflineSyncService _sync;

  Future<List<AppNotification>> load() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.notifications);
    return (response.data ?? const <dynamic>[])
        .map(
          (item) =>
              AppNotification.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<void> markRead(String notificationId) async {
    final endpoint = ApiEndpoints.markNotificationRead(notificationId);
    try {
      await _dio.post<void>(endpoint);
    } catch (error) {
      if (!ApiErrorMapper.isOfflineFailure(error)) rethrow;
      await _sync.enqueue(
        endpoint: endpoint,
        method: 'POST',
        payload: const {},
        entityType: 'notification',
        entityLocalId: notificationId,
        operationType: 'markRead',
      );
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.post<void>(ApiEndpoints.markAllNotificationsRead);
    } catch (error) {
      if (!ApiErrorMapper.isOfflineFailure(error)) rethrow;
      await _sync.enqueue(
        endpoint: ApiEndpoints.markAllNotificationsRead,
        method: 'POST',
        payload: const {},
        entityType: 'notification',
        entityLocalId: 'all',
        operationType: 'markRead',
      );
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    ref.watch(apiClientProvider),
    ref.watch(offlineSyncServiceProvider),
  );
});
