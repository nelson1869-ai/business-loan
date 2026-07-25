import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_router.dart';
import 'core/background/background_sync_worker.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/firebase_mobile_services.dart';
import 'core/telemetry/operational_telemetry.dart';

/// Starts the application inside Riverpod's root provider container.
///
/// File: `lib/main.dart`
///
/// Data Flow Diagram:
/// ```text
///  +------------------+     +------------------+
///  |    main.dart     | --> |     app.dart     |
///  +------------------+     +------------------+
/// ```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  final localNotifications = container.read(localNotificationServiceProvider);
  await localNotifications.initialize(onTap: appRouter.go);
  await FirebaseMobileServices.initialize(
    localNotifications: localNotifications,
    onNavigation: appRouter.go,
  );
  final telemetry = container.read(operationalTelemetryProvider);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    telemetry.recordCrash(
      'flutter_framework',
      details.stack ?? StackTrace.current,
    );
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    telemetry.recordCrash('unhandled_async', stackTrace);
    return true;
  };

  await runZonedGuarded(
    () async {
      await BackgroundSyncWorker.initialize();
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const LendingNelsonApp(),
        ),
      );
    },
    (error, stackTrace) {
      telemetry.recordCrash('root_zone', stackTrace);
    },
  );
}
