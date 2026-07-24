import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_endpoints.dart';
import 'offline_sync_service.dart';

/// Performs fast server health checks to verify backend reachability.
///
/// File: `lib/core/network/server_health_service.dart`
class ServerHealthService {
  /// Creates the service using a shared [Connectivity] instance.
  ServerHealthService(this._connectivity, {this.isServerReachableOverride});

  final Connectivity _connectivity;

  /// Optional override callback for testing environment.
  final Future<bool> Function()? isServerReachableOverride;

  /// Checks if the device has network connectivity and the FastAPI backend is online.
  Future<bool> isServerReachable() async {
    if (isServerReachableOverride != null) {
      return isServerReachableOverride!();
    }

    // 1. Check physical Wi-Fi / Cellular connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    final hasConnection = connectivityResults.any(
      (result) => result != ConnectivityResult.none,
    );
    if (!hasConnection) return false;

    // 2. Perform a fast 1.5-second health ping to verify the backend server is active
    final dio = Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://localhost:8000',
        ),
        connectTimeout: const Duration(milliseconds: 1500),
        receiveTimeout: const Duration(milliseconds: 1500),
      ),
    );

    try {
      final response = await dio.get<Map<String, dynamic>>(ApiEndpoints.health);
      return response.statusCode == 200;
    } on DioException {
      return false;
    } catch (_) {
      return false;
    } finally {
      dio.close(force: true);
    }
  }
}

/// Provider for [ServerHealthService].
final serverHealthServiceProvider = Provider<ServerHealthService>((ref) {
  return ServerHealthService(ref.watch(connectivityProvider));
});
