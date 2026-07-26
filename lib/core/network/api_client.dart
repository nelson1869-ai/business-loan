// ignore_for_file: prefer_initializing_formals

import 'dart:io';

// Third-party packages
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Application routing
import '../../app/app_router.dart';

// Core network
import 'api_endpoints.dart';

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

/// Secure-storage keys used by authentication and request interception.
class TokenStorageKeys {
  TokenStorageKeys._();

  /// Access-token storage key.
  static const String accessToken = 'access_token';

  /// Refresh-token storage key.
  static const String refreshToken = 'refresh_token';
}

/// Configures the shared Dio client used by remote repositories.
class ApiClient {
  /// Creates a client using secure token storage and an authentication callback.
  ApiClient({
    required FlutterSecureStorage secureStorage,
    required void Function() onAuthenticationExpired,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl(),
        connectTimeout: const Duration(seconds: 3),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {'Accept': 'application/json'},
      ),
    );
    _configureCertificatePinning(dio);
    dio.interceptors.add(
      JwtInterceptor(
        dio: dio,
        secureStorage: secureStorage,
        onAuthenticationExpired: onAuthenticationExpired,
      ),
    );
  }

  /// Shared configured Dio instance.
  late final Dio dio;

  void _configureCertificatePinning(Dio client) {
    const configuredPin = String.fromEnvironment('CERTIFICATE_SHA256');
    if (configuredPin.isEmpty) return;
    final expected = configuredPin.replaceAll(':', '').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expected)) {
      throw StateError('CERTIFICATE_SHA256 must be a SHA-256 hex digest');
    }
    client.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: HttpClient.new,
      validateCertificate: (certificate, host, port) {
        if (certificate == null) return false;
        return sha256.convert(certificate.der).toString() == expected;
      },
    );
  }
}

/// Adds JWT access tokens and performs one refresh/retry after a 401 response.
class JwtInterceptor extends Interceptor {
  /// Creates the interceptor for a configured [Dio] instance.
  JwtInterceptor({
    required Dio dio,
    required FlutterSecureStorage secureStorage,
    required void Function() onAuthenticationExpired,
  }) : _dio = dio,
       _secureStorage = secureStorage,
       _onAuthenticationExpired = onAuthenticationExpired;

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  final void Function() _onAuthenticationExpired;
  Future<bool>? _refreshInProgress;

  bool _isAuthenticationPath(String path) {
    return path == ApiEndpoints.token || path == ApiEndpoints.refresh;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthenticationPath(options.path)) {
      final token = await _secureStorage.read(
        key: TokenStorageKeys.accessToken,
      );
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final shouldRefresh =
        err.response?.statusCode == 401 &&
        !_isAuthenticationPath(request.path) &&
        request.extra['jwtRetried'] != true;

    if (!shouldRefresh) {
      handler.next(err);
      return;
    }

    final refreshed = await _refreshOnce();
    if (!refreshed) {
      await _clearTokensAndRedirect();
      handler.next(err);
      return;
    }

    try {
      final token = await _secureStorage.read(
        key: TokenStorageKeys.accessToken,
      );
      final response = await _dio.fetch<dynamic>(
        request.copyWith(
          headers: {...request.headers, 'Authorization': 'Bearer $token'},
          extra: {...request.extra, 'jwtRetried': true},
        ),
      );
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<bool> _refreshOnce() {
    final existing = _refreshInProgress;
    if (existing != null) return existing;
    final refresh = _refreshTokens();
    _refreshInProgress = refresh;
    return refresh.whenComplete(() => _refreshInProgress = null);
  }

  Future<bool> _refreshTokens() async {
    final refreshToken = await _secureStorage.read(
      key: TokenStorageKeys.refreshToken,
    );
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final refreshClient = Dio(_dio.options);
    try {
      final response = await refreshClient.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      final access = data?['access_token'] as String?;
      final rotatedRefresh = data?['refresh_token'] as String?;
      if (access == null || rotatedRefresh == null) return false;
      await Future.wait([
        _secureStorage.write(key: TokenStorageKeys.accessToken, value: access),
        _secureStorage.write(
          key: TokenStorageKeys.refreshToken,
          value: rotatedRefresh,
        ),
      ]);
      return true;
    } on DioException {
      return false;
    }
  }

  Future<void> _clearTokensAndRedirect() async {
    await Future.wait([
      _secureStorage.delete(key: TokenStorageKeys.accessToken),
      _secureStorage.delete(key: TokenStorageKeys.refreshToken),
    ]);
    _onAuthenticationExpired();
  }
}

/// Secure storage instance shared by authentication services.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// Shared authenticated Dio client.
final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(
    secureStorage: storage,
    onAuthenticationExpired: () => appRouter.go('/login'),
  ).dio;
});
