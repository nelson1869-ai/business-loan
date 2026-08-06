import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/core/api/api_error.dart';
import 'package:borrower_mobile/core/auth/auth_state.dart';
import 'package:borrower_mobile/core/storage/secure_token_storage.dart';

final secureStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(
    tokenStorage: storage,
  );
});

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  late final AuthNotifier notifier;
  final apiClient = ApiClient(
    tokenStorage: storage,
    onUnrecoverableAuthError: () {
      notifier.forceLogout();
    },
  );
  notifier = AuthNotifier(storage: storage, apiClient: apiClient);
  return notifier;
});

class AuthNotifier extends StateNotifier<AuthState> {
  final SecureTokenStorage storage;
  final ApiClient apiClient;

  AuthNotifier({
    required this.storage,
    required this.apiClient,
    bool checkAuthOnInit = true,
  }) : super(AuthState.unknown()) {
    if (checkAuthOnInit) {
      checkAuthStatus();
    }
  }

  Future<void> checkAuthStatus() async {
    final token = await storage.getAccessToken();
    final acctId = await storage.getBorrowerAccountId();
    final borId = await storage.getBorrowerId();

    if (token != null && acctId != null && borId != null) {
      try {
        final profile = await apiClient.get('/api/v1/client/me');
        final verifiedAcctId =
            profile['borrowerAccountId'] as String? ?? acctId;
        final verifiedBorId = profile['borrowerId'] as String? ?? borId;

        state = AuthState.authenticated(
          borrowerAccountId: verifiedAcctId,
          borrowerId: verifiedBorId,
        );
      } catch (_) {
        await forceLogout();
      }
    } else {
      await forceLogout();
    }
  }



  Future<bool> activateWithCode({
    required String phoneNumber,
    required String activationCode,
    String? deviceIdentifier,
  }) async {
    final devId = deviceIdentifier ?? await storage.getOrCreateInstallationId();

    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
    );

    try {
      final res = await apiClient.post(
        '/api/v1/client/auth/activate',
        data: {
          'phoneNumber': phoneNumber,
          'activationCode': activationCode,
          'deviceIdentifier': devId,
          'platform': 'android',
        },
      );

      final access = res['accessToken'] as String;
      final refresh = res['refreshToken'] as String;
      final acctId = res['borrowerAccountId'] as String;
      final borId = res['borrowerId'] as String;

      await storage.saveTokens(
        accessToken: access,
        refreshToken: refresh,
        borrowerAccountId: acctId,
        borrowerId: borId,
      );
      await storage.savePhone(phoneNumber);

      state = AuthState.authenticated(
        borrowerAccountId: acctId,
        borrowerId: borId,
      );
      return true;
    } on ApiError catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Account activation failed. Please check the code and try again.',
      );
      return false;
    }
  }

  Future<bool> loginWithPin({
    required String phoneNumber,
    required String pinOrPassword,
    String? deviceIdentifier,
  }) async {
    final devId = deviceIdentifier ?? await storage.getOrCreateInstallationId();

    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
    );

    try {
      final res = await apiClient.post(
        '/api/v1/client/auth/login',
        data: {
          'phoneNumber': phoneNumber,
          'pinOrPassword': pinOrPassword,
          'deviceIdentifier': devId,
        },
      );

      final access = res['accessToken'] as String;
      final refresh = res['refreshToken'] as String;
      final acctId = res['borrowerAccountId'] as String;
      final borId = res['borrowerId'] as String;

      await storage.saveTokens(
        accessToken: access,
        refreshToken: refresh,
        borrowerAccountId: acctId,
        borrowerId: borId,
      );
      await storage.savePhone(phoneNumber);

      state = AuthState.authenticated(
        borrowerAccountId: acctId,
        borrowerId: borId,
      );
      return true;
    } on ApiError catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Login failed. Please check your credentials.',
      );
      return false;
    }
  }

  Future<bool> confirmPin(String pin) async {
    try {
      await apiClient.post(
        '/api/v1/client/auth/confirm-pin',
        data: {'pin': pin},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> requestForgotPin(String phoneNumber) async {
    try {
      final res = await apiClient.post(
        '/api/v1/client/auth/forgot-pin',
        data: {'phoneNumber': phoneNumber},
      );
      return res['message'] as String? ??
          'If the account exists, the owner has been notified.';
    } on ApiError catch (e) {
      return e.message;
    } catch (_) {
      return 'Request failed. Please try again.';
    }
  }

  Future<bool> resetPinWithCode({
    required String phoneNumber,
    required String resetCode,
    required String newPin,
  }) async {
    try {
      await apiClient.post(
        '/api/v1/client/auth/reset-pin',
        data: {
          'phoneNumber': phoneNumber,
          'resetCode': resetCode,
          'newPin': newPin,
        },
      );
      return true;
    } on ApiError catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'PIN reset failed');
      return false;
    }
  }

  Future<void> logout() async {
    state = AuthState.unauthenticated();
    final refreshToken = await storage.getRefreshToken();
    await storage.clearTokens();
    try {
      if (refreshToken != null) {
        await apiClient.post(
          '/api/v1/client/auth/logout',
          data: {'refreshToken': refreshToken},
        );
      }
    } catch (_) {}
  }

  Future<void> forceLogout() async {
    state = AuthState.unauthenticated();
    await storage.clearTokens();
  }
}
