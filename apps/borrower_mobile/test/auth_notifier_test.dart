import 'package:flutter_test/flutter_test.dart';
import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/core/api/api_error.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:borrower_mobile/core/auth/auth_state.dart';
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

class FakeApiClient implements ApiClient {
  final Map<String, dynamic> Function(String path)? onGet;

  @override
  final SecureTokenStorage tokenStorage;

  @override
  final void Function()? onUnrecoverableAuthError;

  FakeApiClient({
    this.onGet,
    SecureTokenStorage? tokenStorage,
    this.onUnrecoverableAuthError,
  }) : tokenStorage = tokenStorage ?? FakeSecureTokenStorage();

  @override
  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    if (onGet != null) {
      return onGet!(path);
    }
    throw const ApiError(message: 'Endpoint not mocked', statusCode: 404);
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    throw const ApiError(message: 'Not implemented', statusCode: 500);
  }

  @override
  Future<void> delete(String path) async {
    throw const ApiError(message: 'Not implemented', statusCode: 500);
  }
}

void main() {
  group('AuthState Model Tests', () {
    test('AuthState.unknown initial state', () {
      final state = AuthState.unknown();
      expect(state.status, equals(AuthStatus.unknown));
      expect(state.borrowerAccountId, isNull);
    });

    test('AuthState.authenticated sets account values', () {
      final state = AuthState.authenticated(
        borrowerAccountId: 'acct-123',
        borrowerId: 'bor-456',
      );
      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.borrowerAccountId, equals('acct-123'));
      expect(state.borrowerId, equals('bor-456'));
    });

    test('AuthState copyWith preserves untouched fields', () {
      final initial = AuthState.authenticated(
        borrowerAccountId: 'acct-123',
        borrowerId: 'bor-456',
      );
      final updated = initial.copyWith(resendCooldownSeconds: 45);
      expect(updated.borrowerAccountId, equals('acct-123'));
      expect(updated.resendCooldownSeconds, equals(45));
    });
  });

  group('AuthNotifier Startup Validation Matrix', () {
    test('No stored tokens -> unauthenticated state', () async {
      final storage = FakeSecureTokenStorage();
      final apiClient = FakeApiClient();
      final notifier = AuthNotifier(storage: storage, apiClient: apiClient);

      await notifier.checkAuthStatus();

      expect(notifier.state.status, equals(AuthStatus.unauthenticated));
    });

    test('Stored valid tokens -> GET /me succeeds -> authenticated state',
        () async {
      final storage = FakeSecureTokenStorage();
      await storage.saveTokens(
        accessToken: 'valid_access_token',
        refreshToken: 'valid_refresh_token',
        borrowerAccountId: 'acct_1',
        borrowerId: 'bor_1',
      );

      final apiClient = FakeApiClient(
        onGet: (path) {
          if (path == '/api/v1/client/me') {
            return {
              'borrowerAccountId': 'acct_1',
              'borrowerId': 'bor_1',
              'firstName': 'Maria',
              'accountStatus': 'active',
            };
          }
          throw const ApiError(message: 'Not found', statusCode: 404);
        },
      );

      final notifier = AuthNotifier(storage: storage, apiClient: apiClient);
      await notifier.checkAuthStatus();

      expect(notifier.state.status, equals(AuthStatus.authenticated));
      expect(notifier.state.borrowerAccountId, equals('acct_1'));
      expect(notifier.state.borrowerId, equals('bor_1'));
    });

    test(
        'Stored tokens but GET /me returns 401/suspended -> clear tokens & unauthenticated state',
        () async {
      final storage = FakeSecureTokenStorage();
      await storage.saveTokens(
        accessToken: 'expired_or_suspended_token',
        refreshToken: 'revoked_refresh_token',
        borrowerAccountId: 'acct_1',
        borrowerId: 'bor_1',
      );

      final apiClient = FakeApiClient(
        onGet: (path) {
          throw const ApiError(message: 'Account suspended', statusCode: 401);
        },
      );

      final notifier = AuthNotifier(storage: storage, apiClient: apiClient);
      await notifier.checkAuthStatus();

      expect(notifier.state.status, equals(AuthStatus.unauthenticated));
      expect(await storage.getAccessToken(), isNull);
    });
  });
}
