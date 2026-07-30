import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

/// Privacy-safe Android notification categories used by local reminders.
enum ReminderCategory {
  collections,
  promises,
  payments,
  overdue,
  administration,
}

/// Manages local notification permission, channels, and scheduled reminders.
class LocalNotificationService {
  LocalNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channel = AndroidNotificationChannel(
    'lending_reminders',
    'Lending reminders',
    description: 'Operational reminders without borrower financial details.',
    importance: Importance.high,
  );

  /// Initializes channels and tap handling.
  Future<void> initialize({void Function(String payload)? onTap}) async {
    timezone_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap?.call(payload);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  /// Requests Android 13+ notification permission.
  Future<bool> requestPermission() async {
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        true;
  }

  /// Schedules one operational reminder without embedding PII.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required String navigationPath,
    required ReminderCategory category,
  }) async {
    if (!at.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'lending_reminders',
          'Lending reminders',
          channelDescription:
              'Operational reminders without borrower financial details.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
      payload: navigationPath,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Removes reminders whose operational records are no longer active.
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return LocalNotificationService(FlutterLocalNotificationsPlugin());
});
