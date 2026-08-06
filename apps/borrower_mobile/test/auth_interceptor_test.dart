import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:borrower_mobile/core/api/auth_interceptor.dart';
import 'package:borrower_mobile/core/storage/secure_token_storage.dart';

class FakeSecureTokenStorage implements SecureTokenStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> getAccessToken() async => _storage['access_token'];

  @override
  Future<String?> getRefreshToken() async => _storage['refresh_token'];

  @override
  Future<String?> getBorrowerAccountId() async => _storage['account_id'];

  @override
  Future<String?> getBorrowerId() async => _storage['borrower_id'];

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String borrowerAccountId,
    required String borrowerId,
  }) async {
    _storage['access_token'] = accessToken;
    _storage['refresh_token'] = refreshToken;
    _storage['account_id'] = borrowerAccountId;
    _storage['borrower_id'] = borrowerId;
  }

  @override
  Future<void> clearTokens() async {
    _storage.clear();
  }

  @override
  Future<String> getOrCreateInstallationId() async =>
      _storage['installation_id'] ??= 'fake-test-installation-id';

  @override
  Future<String?> getSavedPhone() async => _storage['saved_phone'];

  @override
  Future<void> savePhone(String phone) async {
    _storage['saved_phone'] = phone;
  }
}

class TestRequestInterceptorHandler extends RequestInterceptorHandler {
  RequestOptions? options;

  @override
  void next(RequestOptions requestOptions) {
    options = requestOptions;
  }
}

class TestErrorInterceptorHandler extends ErrorInterceptorHandler {
  DioException? error;
  Response? response;

  @override
  void next(DioException err) {
    error = err;
  }

  @override
  void resolve(Response res) {
    response = res;
  }
}

void main() {
  late FakeSecureTokenStorage tokenStorage;
  late Dio dio;
  late Dio refreshDio;
  late AuthInterceptor interceptor;
  int unrecoverableCallCount = 0;

  setUp(() {
    tokenStorage = FakeSecureTokenStorage();
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    refreshDio = Dio(BaseOptions(baseUrl: 'http://test'));
    unrecoverableCallCount = 0;

    interceptor = AuthInterceptor(
      tokenStorage: tokenStorage,
      dio: dio,
      refreshDio: refreshDio,
      onUnrecoverableAuthError: () {
        unrecoverableCallCount++;
      },
    );
  });

  test('Attaches Bearer access token to authorized request', () async {
    await tokenStorage.saveTokens(
      accessToken: 'valid_access_token_123',
      refreshToken: 'valid_refresh_token_123',
      borrowerAccountId: 'acct_1',
      borrowerId: 'bor_1',
    );

    final options = RequestOptions(path: '/api/v1/client/me');
    final handler = TestRequestInterceptorHandler();

    await interceptor.onRequest(options, handler);

    expect(
      options.headers['Authorization'],
      equals('Bearer valid_access_token_123'),
    );
  });

  test('Excludes non-retryable auth endpoints from attaching access token',
      () async {
    await tokenStorage.saveTokens(
      accessToken: 'valid_access_token_123',
      refreshToken: 'valid_refresh_token_123',
      borrowerAccountId: 'acct_1',
      borrowerId: 'bor_1',
    );

    for (final path in [
      '/api/v1/client/auth/activate',
      '/api/v1/client/auth/login',
      '/api/v1/client/auth/refresh',
      '/api/v1/client/auth/logout',
    ]) {
      final options = RequestOptions(path: path);
      final handler = TestRequestInterceptorHandler();
      await interceptor.onRequest(options, handler);
      expect(options.headers['Authorization'], isNull,
          reason: 'Failed for path: $path');
    }
  });

  test(
      'Triggers unrecoverable auth error callback when refresh token is missing',
      () async {
    final dioErr = DioException(
      requestOptions: RequestOptions(path: '/api/v1/client/me'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/v1/client/me'),
        statusCode: 401,
      ),
    );
    final handler = TestErrorInterceptorHandler();

    await interceptor.onError(dioErr, handler);

    expect(unrecoverableCallCount, equals(1));
    expect(await tokenStorage.getAccessToken(), isNull);
  });

  test('Does not retry requests that already attempted auth retry', () async {
    await tokenStorage.saveTokens(
      accessToken: 'valid_access_token_123',
      refreshToken: 'valid_refresh_token_123',
      borrowerAccountId: 'acct_1',
      borrowerId: 'bor_1',
    );

    final dioErr = DioException(
      requestOptions: RequestOptions(
        path: '/api/v1/client/me',
        extra: {'authRetryAttempted': true},
      ),
      response: Response(
        requestOptions: RequestOptions(path: '/api/v1/client/me'),
        statusCode: 401,
      ),
    );
    final handler = TestErrorInterceptorHandler();

    await interceptor.onError(dioErr, handler);

    expect(handler.error, equals(dioErr));
    expect(unrecoverableCallCount, equals(0));
  });

  test('Does not retry 401 errors on non-retryable auth endpoints', () async {
    await tokenStorage.saveTokens(
      accessToken: 'valid_access_token_123',
      refreshToken: 'valid_refresh_token_123',
      borrowerAccountId: 'acct_1',
      borrowerId: 'bor_1',
    );

    for (final path in [
      '/api/v1/client/auth/activate',
      '/api/v1/client/auth/login',
      '/api/v1/client/auth/refresh',
      '/api/v1/client/auth/logout',
    ]) {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 401,
        ),
      );
      final handler = TestErrorInterceptorHandler();

      await interceptor.onError(dioErr, handler);

      expect(handler.error, equals(dioErr));
      expect(unrecoverableCallCount, equals(0));
    }
  });

  test(
      'Safe logout triggered when refresh response contains malformed data or network fails',
      () async {
    await tokenStorage.saveTokens(
      accessToken: 'expired_access_token',
      refreshToken: 'revoked_refresh_token',
      borrowerAccountId: 'acct_1',
      borrowerId: 'bor_1',
    );

    final dioErr = DioException(
      requestOptions: RequestOptions(path: '/api/v1/client/me'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/v1/client/me'),
        statusCode: 401,
      ),
    );
    final handler = TestErrorInterceptorHandler();

    await interceptor.onError(dioErr, handler);

    expect(unrecoverableCallCount, equals(1));
    expect(await tokenStorage.getAccessToken(), isNull);
    expect(await tokenStorage.getRefreshToken(), isNull);
  });
}
