import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_repository.dart';
import '../domain/dashboard_data.dart';
import '../../../core/notifications/local_notification_service.dart';

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this._repository, this._notifications)
    : super(const DashboardState());

  final DashboardRepository _repository;
  final LocalNotificationService _notifications;

  Future<void> loadDashboard() async {
    state = const DashboardState(isLoading: true);
    state = await _repository.loadDashboard();
    if (state.dueItems.isNotEmpty) {
      await _notifications.requestPermission();
      for (final item in state.dueItems.take(20)) {
        await _notifications.schedule(
          id: _notificationId('${item.loanId}:${item.installmentNumber}'),
          title: item.isOverdue
              ? 'Overdue account follow-up'
              : "Today's collection",
          body: 'An assigned lending task requires attention.',
          at: DateTime.now().add(const Duration(minutes: 5)),
          navigationPath: '/collections/today',
          category: item.isOverdue
              ? ReminderCategory.overdue
              : ReminderCategory.collections,
        );
      }
    }
  }

  int _notificationId(String value) {
    return value.codeUnits.fold<int>(17, (hash, code) {
      return ((hash * 31) + code) & 0x7fffffff;
    });
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
      return DashboardNotifier(
        ref.watch(dashboardRepositoryProvider),
        ref.watch(localNotificationServiceProvider),
      );
    });
