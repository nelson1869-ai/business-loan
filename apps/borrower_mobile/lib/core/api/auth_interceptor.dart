import 'package:dio/dio.dart';
import 'package:borrower_mobile/core/storage/secure_token_storage.dart';

/// Interceptor attaching borrower JWT access tokens and handling automatic refresh.
class AuthInterceptor extends Interceptor {
  final SecureTokenStorage tokenStorage;
  final Dio dio;
  final void Function()? onUnrecoverableAuthError;

  bool _isRefreshing = false;

  AuthInterceptor({
    required this.tokenStorage,
    required this.dio,
    this.onUnrecoverableAuthError,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await tokenStorage.getRefreshToken();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          final refreshResponse = await dio.post(
            '/api/v1/client/auth/refresh',
            data: {'refreshToken': refreshToken},
            options: Options(headers: {'Authorization': ''}),
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

            _isRefreshing = false;
            final requestOptions = err.requestOptions;
            requestOptions.headers['Authorization'] = 'Bearer $newAccess';
            final cloneResponse = await dio.fetch(requestOptions);
            return handler.resolve(cloneResponse);
          }
        }
      } catch (_) {
        // Refresh failed or revoked
      } finally {
        _isRefreshing = false;
      }

      await tokenStorage.clearTokens();
      onUnrecoverableAuthError?.call();
    }
    handler.next(err);
  }
}
