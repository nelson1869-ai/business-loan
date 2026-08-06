import 'dart:async';
import 'package:dio/dio.dart';
import 'package:borrower_mobile/core/storage/secure_token_storage.dart';

/// Interceptor attaching borrower JWT access tokens and handling automatic token refresh.
class AuthInterceptor extends Interceptor {
  final SecureTokenStorage tokenStorage;
  final Dio dio;
  final void Function()? onUnrecoverableAuthError;
  final Dio _refreshDio;

  Completer<bool>? _refreshCompleter;

  static const _nonRetryableRoutes = {
    '/api/v1/client/auth/activate',
    '/api/v1/client/auth/login',
    '/api/v1/client/auth/refresh',
    '/api/v1/client/auth/logout',
  };

  AuthInterceptor({
    required this.tokenStorage,
    required this.dio,
    this.onUnrecoverableAuthError,
    Dio? refreshDio,
  }) : _refreshDio = refreshDio ??
            Dio(
              BaseOptions(
                baseUrl: dio.options.baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final path = options.path;
    final isAuthEndpoint =
        _nonRetryableRoutes.any((route) => path.contains(route));

    if (!isAuthEndpoint) {
      final token = await tokenStorage.getAccessToken();
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
    final response = err.response;
    final requestOptions = err.requestOptions;
    final path = requestOptions.path;

    final isAuthEndpoint =
        _nonRetryableRoutes.any((route) => path.contains(route));
    final alreadyRetried = requestOptions.extra['authRetryAttempted'] == true;

    if (response?.statusCode == 401 && !isAuthEndpoint && !alreadyRetried) {
      requestOptions.extra['authRetryAttempted'] = true;

      final refreshSuccess = await _performOrWaitRefresh();
      if (refreshSuccess) {
        final newToken = await tokenStorage.getAccessToken();
        if (newToken != null && newToken.isNotEmpty) {
          requestOptions.headers['Authorization'] = 'Bearer $newToken';
          try {
            final cloneResponse = await dio.fetch(requestOptions);
            return handler.resolve(cloneResponse);
          } on DioException catch (retryErr) {
            return handler.next(retryErr);
          }
        }
      }
    }
    handler.next(err);
  }

  Future<bool> _performOrWaitRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;
    var success = false;

    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        final refreshResponse = await _refreshDio.post(
          '/api/v1/client/auth/refresh',
          data: {'refreshToken': refreshToken},
        );

        if (refreshResponse.statusCode == 200) {
          final data = refreshResponse.data as Map<String, dynamic>;
          final newAccess = data['accessToken'] as String;
          final newRefresh = data['refreshToken'] as String;
          final acctId = data['borrowerAccountId'] as String;
          final borId = data['borrowerId'] as String;

          await tokenStorage.saveTokens(
            accessToken: newAccess,
            refreshToken: newRefresh,
            borrowerAccountId: acctId,
            borrowerId: borId,
          );
          success = true;
        }
      }
    } catch (_) {
      success = false;
    }

    if (!success) {
      await tokenStorage.clearTokens();
      onUnrecoverableAuthError?.call();
    }

    completer.complete(success);
    _refreshCompleter = null;
    return success;
  }
}
