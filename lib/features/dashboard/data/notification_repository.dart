import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/app_notification.dart';

class NotificationRepository {
  const NotificationRepository(this._dio);

  final Dio _dio;

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
    await _dio.post<void>(ApiEndpoints.markNotificationRead(notificationId));
  }

  Future<void> markAllRead() async {
    await _dio.post<void>(ApiEndpoints.markAllNotificationsRead);
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});
