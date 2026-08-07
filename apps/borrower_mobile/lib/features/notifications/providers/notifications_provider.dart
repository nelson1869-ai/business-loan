import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:borrower_mobile/features/notifications/data/notifications_repository.dart';
import 'package:borrower_mobile/features/notifications/models/borrower_notification.dart';

class NotificationsState {
  final bool isLoading;
  final bool isRefreshing;
  final List<BorrowerNotificationItem> notifications;
  final int unreadCount;
  final String? errorMessage;
  final bool hasMore;

  const NotificationsState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.notifications = const [],
    this.unreadCount = 0,
    this.errorMessage,
    this.hasMore = true,
  });

  NotificationsState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    List<BorrowerNotificationItem>? notifications,
    int? unreadCount,
    String? errorMessage,
    bool clearError = false,
    bool? hasMore,
  }) {
    return NotificationsState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationsRepository repository;

  NotificationsNotifier({required this.repository})
      : super(const NotificationsState());

  Future<void> loadNotifications({bool isRefresh = false}) async {
    if (isRefresh) {
      state = state.copyWith(isRefreshing: true, clearError: true);
    } else if (state.notifications.isEmpty) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final fetched = await repository.getNotifications(limit: 50, offset: 0);
      final unread = await repository.getUnreadCount();

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        notifications: fetched,
        unreadCount: unread,
        hasMore: fetched.length >= 50,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    try {
      final nextChunk = await repository.getNotifications(
        limit: 50,
        offset: state.notifications.length,
      );
      state = state.copyWith(
        notifications: [...state.notifications, ...nextChunk],
        hasMore: nextChunk.length >= 50,
      );
    } catch (_) {}
  }

  Future<void> markAsRead(String notificationId) async {
    final index =
        state.notifications.indexWhere((item) => item.id == notificationId);
    if (index == -1) return;

    final target = state.notifications[index];
    if (target.isRead) return;

    final updatedList = List<BorrowerNotificationItem>.from(state.notifications);
    updatedList[index] = target.copyWith(isRead: true);

    final previousCount = state.unreadCount;
    final newCount = (previousCount - 1).clamp(0, 999999);

    // Optimistic update
    state = state.copyWith(
      notifications: updatedList,
      unreadCount: newCount,
    );

    try {
      await repository.markAsRead(notificationId);
    } catch (_) {
      // Revert state if remote call fails
      state = state.copyWith(
        notifications: state.notifications,
        unreadCount: previousCount,
      );
    }
  }

  Future<void> markAllAsRead() async {
    if (state.unreadCount == 0) return;

    final previousList = List<BorrowerNotificationItem>.from(state.notifications);
    final previousCount = state.unreadCount;

    final updatedList = state.notifications
        .map((item) => item.isRead ? item : item.copyWith(isRead: true))
        .toList();

    state = state.copyWith(
      notifications: updatedList,
      unreadCount: 0,
    );

    try {
      await repository.markAllAsRead();
    } catch (_) {
      state = state.copyWith(
        notifications: previousList,
        unreadCount: previousCount,
      );
    }
  }

  void clearState() {
    state = const NotificationsState();
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationsRepository(apiClient: apiClient);
});

final notificationsNotifierProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  final notifier = NotificationsNotifier(repository: repo);
  notifier.loadNotifications();
  return notifier;
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsNotifierProvider).unreadCount;
});
