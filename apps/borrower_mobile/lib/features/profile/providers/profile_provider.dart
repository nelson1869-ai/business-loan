import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:borrower_mobile/features/profile/data/profile_repository.dart';
import 'package:borrower_mobile/features/profile/models/borrower_device.dart';
import 'package:borrower_mobile/features/profile/models/borrower_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProfileRepository(apiClient: apiClient);
});

class ProfileState {
  final bool isLoading;
  final BorrowerProfile? profile;
  final DeviceResponse? deviceRegistration;
  final String? errorMessage;

  const ProfileState({
    this.isLoading = false,
    this.profile,
    this.deviceRegistration,
    this.errorMessage,
  });

  ProfileState copyWith({
    bool? isLoading,
    BorrowerProfile? profile,
    DeviceResponse? deviceRegistration,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
      deviceRegistration: deviceRegistration ?? this.deviceRegistration,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository repository;
  final String borrowerAccountId;

  ProfileNotifier({
    required this.repository,
    required this.borrowerAccountId,
  }) : super(const ProfileState()) {
    if (borrowerAccountId.isNotEmpty) {
      loadProfile();
      registerCurrentDevice();
    }
  }

  Future<void> loadProfile() async {
    if (state.profile == null) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final profile = await repository.getProfile(
        borrowerAccountId: borrowerAccountId,
      );
      state = state.copyWith(
        isLoading: false,
        profile: profile,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> registerCurrentDevice({
    String deviceIdentifier = 'borrower-mobile-app',
    String platform = 'android',
    String? pushToken,
  }) async {
    try {
      final request = DeviceRegisterRequest(
        deviceIdentifier: deviceIdentifier,
        platform: platform,
        pushToken: pushToken,
      );
      final response = await repository.registerDevice(
        borrowerAccountId: borrowerAccountId,
        request: request,
      );
      state = state.copyWith(deviceRegistration: response);
    } catch (_) {}
  }
}

final profileNotifierProvider =
    StateNotifierProvider.autoDispose<ProfileNotifier, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final accountId = ref.watch(
    authNotifierProvider.select((auth) => auth.borrowerAccountId),
  );

  return ProfileNotifier(
    repository: repository,
    borrowerAccountId: accountId ?? '',
  );
});
