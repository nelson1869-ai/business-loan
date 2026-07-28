import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../network/offline_sync_service.dart';

const _syncTaskName = 'lending_nelson_background_sync';

/// WorkManager entry point used after process death or device reboot.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final container = ProviderContainer();
    try {
      await container.read(offlineSyncServiceProvider).drainQueue();
      return true;
    } catch (_) {
      return false;
    } finally {
      container.dispose();
    }
  });
}

/// Configures battery-conscious, network-constrained queue processing.
class BackgroundSyncWorker {
  /// Initializes WorkManager and registers a single batched periodic job.
  static Future<void> initialize() async {
    await Workmanager().initialize(backgroundSyncDispatcher);
    await Workmanager().registerPeriodicTask(
      _syncTaskName,
      _syncTaskName,
      frequency: const Duration(minutes: 30),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 10),
    );
  }

  /// Requests an immediate network-constrained retry.
  static Future<void> requestImmediateSync() {
    return Workmanager().registerOneOffTask(
      '${_syncTaskName}_${DateTime.now().millisecondsSinceEpoch}',
      _syncTaskName,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  }
}
