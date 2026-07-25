import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_sync_service.dart';

String _apiBaseUrl() {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isEmpty) {
    if (kReleaseMode) {
      throw StateError('API_BASE_URL is required for release builds');
    }
    return 'http://localhost:8000';
  }
  final uri = Uri.tryParse(configured);
  if (uri == null ||
      !uri.hasAuthority ||
      (kReleaseMode && uri.scheme != 'https')) {
    throw StateError(
      'API_BASE_URL must be a valid HTTPS URL in release builds',
    );
  }
  return configured;
}

/// Explicit status representing device network and backend reachability.
enum ServerStatus { offline, networkAvailable, serverUnavailable, serverReady }

/// Performs fast server health checks to verify backend reachability.
///
/// File: `lib/core/network/server_health_service.dart`
class ServerHealthService {
  /// Creates the service using a shared [Connectivity] instance.
  ServerHealthService(
    this._connectivity, {
    this.isServerReachableOverride,
    this.isForcedOffline,
  });

  final Connectivity _connectivity;

  /// Optional override callback for testing environment.
  final Future<bool> Function()? isServerReachableOverride;
  final bool Function()? isForcedOffline;

  bool _isChecking = false;
  DateTime? _lastCheckAt;

  /// Evaluates exact device network connectivity and server readiness.
  Future<ServerStatus> checkStatus() async {
    if (isForcedOffline?.call() ?? false) {
      return ServerStatus.offline;
    }

    if (isServerReachableOverride != null) {
      final reachable = await isServerReachableOverride!();
      return reachable
          ? ServerStatus.serverReady
          : ServerStatus.serverUnavailable;
    }

    // 1. Check physical network interface status
    final connectivityResults = await _connectivity.checkConnectivity();
    final hasNetwork = connectivityResults.any(
      (result) => result != ConnectivityResult.none,
    );
    if (!hasNetwork) return ServerStatus.offline;

    // Cooldown check (prevent tight polling loop if called frequently)
    if (_lastCheckAt != null &&
        DateTime.now().difference(_lastCheckAt!) < const Duration(seconds: 2)) {
      return ServerStatus.networkAvailable;
    }

    if (_isChecking) return ServerStatus.networkAvailable;
    _isChecking = true;
    _lastCheckAt = DateTime.now();

    final dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl(),
        connectTimeout: const Duration(milliseconds: 2000),
        receiveTimeout: const Duration(milliseconds: 2000),
      ),
    );

    try {
      final response = await dio.get<Map<String, dynamic>>('/health/ready');
      if (response.statusCode == 200 && response.data != null) {
        final statusStr = response.data!['status'] as String?;
        if (statusStr == 'ready' || statusStr == 'ok') {
          return ServerStatus.serverReady;
        }
      }
      return ServerStatus.serverUnavailable;
    } on DioException {
      return ServerStatus.serverUnavailable;
    } catch (_) {
      return ServerStatus.serverUnavailable;
    } finally {
      dio.close(force: true);
      _isChecking = false;
    }
  }

  /// Convenience helper returning true only if server is verified ready.
  Future<bool> isServerReachable() async {
    final status = await checkStatus();
    return status == ServerStatus.serverReady;
  }
}

/// Reactive notifier managing process-wide [ServerStatus].
class ServerStatusNotifier extends StateNotifier<ServerStatus> {
  ServerStatusNotifier(this._service, this._connectivity)
    : super(ServerStatus.offline) {
    _init();
  }

  final ServerHealthService _service;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _pollingTimer;

  void _init() {
    refreshStatus();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (!hasConnection) {
        state = ServerStatus.offline;
      } else {
        state = ServerStatus.networkAvailable;
        refreshStatus();
      }
    });

    // Background periodic health probe every 15 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refreshStatus();
    });
  }

  /// Triggers an immediate status evaluation.
  Future<void> refreshStatus() async {
    final newStatus = await _service.checkStatus();
    state = newStatus;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }
}

/// Provider for [ServerHealthService].
final serverHealthServiceProvider = Provider<ServerHealthService>((ref) {
  return ServerHealthService(
    ref.watch(connectivityProvider),
    isForcedOffline: () => ref.read(forcedOfflineModeProvider),
  );
});

/// Reactive provider for process-wide [ServerStatus].
final serverStatusNotifierProvider =
    StateNotifierProvider<ServerStatusNotifier, ServerStatus>((ref) {
      return ServerStatusNotifier(
        ref.watch(serverHealthServiceProvider),
        ref.watch(connectivityProvider),
      );
    });
