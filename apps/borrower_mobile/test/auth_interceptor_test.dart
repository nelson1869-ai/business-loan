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
  bool unrecoverableCalled = false;

  setUp(() {
    tokenStorage = FakeSecureTokenStorage();
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    refreshDio = Dio(BaseOptions(baseUrl: 'http://test'));
    unrecoverableCalled = false;

    interceptor = AuthInterceptor(
      tokenStorage: tokenStorage,
      dio: dio,
      refreshDio: refreshDio,
      onUnrecoverableAuthError: () {
        unrecoverableCalled = true;
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

    final options = RequestOptions(path: '/api/v1/client/auth/request-otp');
    final handler = TestRequestInterceptorHandler();

    await interceptor.onRequest(options, handler);

    expect(options.headers['Authorization'], isNull);
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

    expect(unrecoverableCalled, isTrue);
    expect(await tokenStorage.getAccessToken(), isNull);
  });
}
