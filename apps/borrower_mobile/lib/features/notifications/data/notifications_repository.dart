import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/features/notifications/models/borrower_notification.dart';

class NotificationsRepository {
  final ApiClient apiClient;

  NotificationsRepository({required this.apiClient});

  Future<List<BorrowerNotificationItem>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final list = await apiClient.getList(
      '/api/v1/client/me/notifications?limit=$limit&offset=$offset',
    );
    return list
        .map((item) => BorrowerNotificationItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final json = await apiClient.get('/api/v1/client/me/notifications/unread-count');
    return (json['unreadCount'] ?? json['unread_count']) as int? ?? 0;
  }

  Future<void> markAsRead(String notificationId) async {
    await apiClient.post('/api/v1/client/me/notifications/$notificationId/read');
  }

  Future<void> markAllAsRead() async {
    await apiClient.post('/api/v1/client/me/notifications/read-all');
  }
}
