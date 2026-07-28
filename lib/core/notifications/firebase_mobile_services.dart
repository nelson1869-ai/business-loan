import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../telemetry/operational_telemetry.dart';
import 'local_notification_service.dart';

const _firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
const _firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const _firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

bool get _hasFirebaseConfiguration =>
    _firebaseApiKey.isNotEmpty &&
    _firebaseAppId.isNotEmpty &&
    _firebaseSenderId.isNotEmpty &&
    _firebaseProjectId.isNotEmpty;

FirebaseOptions get _firebaseOptions => const FirebaseOptions(
  apiKey: _firebaseApiKey,
  appId: _firebaseAppId,
  messagingSenderId: _firebaseSenderId,
  projectId: _firebaseProjectId,
);

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  if (!_hasFirebaseConfiguration) return;
  await Firebase.initializeApp(options: _firebaseOptions);
}

/// Credential-gated FCM, Crashlytics, and anonymous analytics integration.
class FirebaseMobileServices {
  FirebaseMobileServices._();

  static Future<bool> initialize({
    required LocalNotificationService localNotifications,
    required void Function(String path) onNavigation,
  }) async {
    if (!_hasFirebaseConfiguration) return false;
    await Firebase.initializeApp(options: _firebaseOptions);
    OperationalTelemetryRegistry.current = FirebaseOperationalTelemetry();
    await _configureNonIdentifyingCrashContext();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await localNotifications.requestPermission();

    FirebaseMessaging.onMessage.listen((message) {
      final category = _category(message.data['category'] as String?);
      unawaited(
        localNotifications.schedule(
          id: message.messageId.hashCode,
          title: _safeTitle(category),
          body: 'New lending activity requires your attention.',
          at: DateTime.now().add(const Duration(seconds: 1)),
          navigationPath: _safePath(message.data['path'] as String?),
          category: category,
        ),
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onNavigation(_safePath(message.data['path'] as String?));
    });
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      onNavigation(_safePath(initial.data['path'] as String?));
    }
    return true;
  }

  static Future<void> _configureNonIdentifyingCrashContext() async {
    final crashlytics = FirebaseCrashlytics.instance;
    final package = await PackageInfo.fromPlatform();
    await crashlytics.setCustomKey('app_version', package.version);
    await crashlytics.setCustomKey('app_build', package.buildNumber);
    if (Platform.isAndroid) {
      final android = await DeviceInfoPlugin().androidInfo;
      await crashlytics.setCustomKey(
        'android_release',
        android.version.release,
      );
      await crashlytics.setCustomKey('android_sdk', android.version.sdkInt);
    }
  }

  static ReminderCategory _category(String? value) {
    return switch (value) {
      'collection' => ReminderCategory.collections,
      'promise' => ReminderCategory.promises,
      'payment' => ReminderCategory.payments,
      'overdue' => ReminderCategory.overdue,
      _ => ReminderCategory.administration,
    };
  }

  static String _safeTitle(ReminderCategory category) {
    return switch (category) {
      ReminderCategory.collections => 'Collection assignment',
      ReminderCategory.promises => 'Promise reminder',
      ReminderCategory.payments => 'Payment reminder',
      ReminderCategory.overdue => 'Overdue account reminder',
      ReminderCategory.administration => 'Administration announcement',
    };
  }

  static String _safePath(String? value) {
    if (value == null) return '/notifications';
    final allowed = <RegExp>[
      RegExp(r'^/notifications$'),
      RegExp(r'^/collections/today$'),
      RegExp(r'^/borrowers/[0-9a-fA-F-]{36}$'),
      RegExp(r'^/loans/[0-9a-fA-F-]{36}$'),
    ];
    return allowed.any((pattern) => pattern.hasMatch(value))
        ? value
        : '/notifications';
  }
}

class FirebaseOperationalTelemetry implements OperationalTelemetry {
  FirebaseOperationalTelemetry()
    : _analytics = FirebaseAnalytics.instance,
      _crashlytics = FirebaseCrashlytics.instance;

  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;

  static const _allowedEvents = {
    'sync_success',
    'sync_failure',
    'upload_duration',
    'startup_duration',
    'navigation_duration',
  };

  @override
  void record(String event, {Map<String, num> measurements = const {}}) {
    if (!_allowedEvents.contains(event)) return;
    unawaited(
      _analytics.logEvent(
        name: event,
        parameters: measurements.map(
          (key, value) => MapEntry(key, value as Object),
        ),
      ),
    );
  }

  @override
  void recordCrash(String category, StackTrace stackTrace) {
    unawaited(
      _crashlytics.recordError(
        StateError(category),
        stackTrace,
        reason: 'Non-PII application failure',
      ),
    );
  }
}
