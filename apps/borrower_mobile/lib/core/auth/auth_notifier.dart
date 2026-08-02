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

  Future<bool> requestOtp({
    required String phoneNumber,
    String? invitationCode,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
    );

    try {
      final res = await apiClient.post(
        '/api/v1/client/auth/request-otp',
        data: {
          'phoneNumber': phoneNumber,
          if (invitationCode != null && invitationCode.isNotEmpty)
            'invitationCode': invitationCode,
        },
      );
      final cooldown = (res['resendCooldownSeconds'] as num?)?.toInt() ?? 60;
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        pendingPhoneNumber: phoneNumber,
        resendCooldownSeconds: cooldown,
      );
      return true;
    } on ApiError catch (e) {
      state = AuthState.unauthenticated(e.message);
      return false;
    } catch (e) {
      state = AuthState.unauthenticated('Failed to request OTP');
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String otp,
    String? invitationCode,
    required String deviceIdentifier,
  }) async {
    final phone = state.pendingPhoneNumber;
    if (phone == null || phone.isEmpty) {
      state = AuthState.unauthenticated('Phone number missing');
      return false;
    }

    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
    );

    try {
      final res = await apiClient.post(
        '/api/v1/client/auth/verify-otp',
        data: {
          'phoneNumber': phone,
          'otp': otp,
          if (invitationCode != null && invitationCode.isNotEmpty)
            'invitationCode': invitationCode,
          'deviceIdentifier': deviceIdentifier,
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
        errorMessage: 'OTP verification failed',
      );
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
