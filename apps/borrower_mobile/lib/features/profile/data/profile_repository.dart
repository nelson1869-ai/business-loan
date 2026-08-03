import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/features/profile/data/profile_local_cache.dart';
import 'package:borrower_mobile/features/profile/models/borrower_device.dart';
import 'package:borrower_mobile/features/profile/models/borrower_profile.dart';

class ProfileRepository {
  final ApiClient apiClient;
  final ProfileLocalCache localCache;

  ProfileRepository({
    required this.apiClient,
    ProfileLocalCache? localCache,
  }) : localCache = localCache ?? ProfileLocalCache();

  Future<BorrowerProfile> getProfile({
    required String borrowerAccountId,
  }) async {
    if (borrowerAccountId.trim().isEmpty) {
      throw ArgumentError.value(
        borrowerAccountId,
        'borrowerAccountId',
        'must not be empty',
      );
    }
    try {
      final json = await apiClient.get('/api/v1/client/me');
      final profile = BorrowerProfile.fromJson(json, isFromCache: false);
      await localCache.saveCachedProfile(borrowerAccountId, profile);
      return profile;
    } catch (e) {
      final cached = await localCache.getCachedProfile(borrowerAccountId);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<DeviceResponse> registerDevice({
    required String borrowerAccountId,
    required DeviceRegisterRequest request,
  }) async {
    if (borrowerAccountId.trim().isEmpty) {
      throw ArgumentError.value(
        borrowerAccountId,
        'borrowerAccountId',
        'must not be empty',
      );
    }
    try {
      final json = await apiClient.post(
        '/api/v1/client/devices',
        data: request.toJson(),
      );
      final response = DeviceResponse.fromJson(json);
      await localCache.saveCachedDeviceRegistration(
          borrowerAccountId, response);
      return response;
    } catch (e) {
      final cached =
          await localCache.getCachedDeviceRegistration(borrowerAccountId);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }
}
