import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_repository.dart';
import '../domain/app_notification.dart';

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) {
    return ref.watch(notificationRepositoryProvider).load();
  },
);
