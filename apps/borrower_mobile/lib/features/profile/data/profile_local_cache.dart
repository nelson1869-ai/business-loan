import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:borrower_mobile/features/profile/models/borrower_device.dart';
import 'package:borrower_mobile/features/profile/models/borrower_profile.dart';

class ProfileLocalCache {
  final FlutterSecureStorage _storage;

  ProfileLocalCache({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  String _requireAccountId(String borrowerAccountId) {
    final accountId = borrowerAccountId.trim();
    if (accountId.isEmpty) {
      throw ArgumentError.value(
        borrowerAccountId,
        'borrowerAccountId',
        'must not be empty',
      );
    }
    return accountId;
  }

  String _profileKey(String borrowerAccountId) {
    final accountId = _requireAccountId(borrowerAccountId);
    return 'cached_profile_$accountId';
  }

  String _deviceKey(String borrowerAccountId) {
    final accountId = _requireAccountId(borrowerAccountId);
    return 'cached_device_$accountId';
  }

  Future<BorrowerProfile?> getCachedProfile(String borrowerAccountId) async {
    final key = _profileKey(borrowerAccountId);
    try {
      final rawJson = await _storage.read(key: key);
      if (rawJson == null || rawJson.isEmpty) {
        return null;
      }
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return BorrowerProfile.fromJson(map, isFromCache: true);
    } catch (_) {
      await _storage.delete(key: key).catchError((_) {});
      return null;
    }
  }

  Future<void> saveCachedProfile(
    String borrowerAccountId,
    BorrowerProfile profile,
  ) async {
    final key = _profileKey(borrowerAccountId);
    final rawJson = jsonEncode(profile.toJson());
    await _storage.write(key: key, value: rawJson);
  }

  Future<DeviceResponse?> getCachedDeviceRegistration(
      String borrowerAccountId) async {
    final key = _deviceKey(borrowerAccountId);
    try {
      final rawJson = await _storage.read(key: key);
      if (rawJson == null || rawJson.isEmpty) {
        return null;
      }
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return DeviceResponse.fromJson(map);
    } catch (_) {
      await _storage.delete(key: key).catchError((_) {});
      return null;
    }
  }

  Future<void> saveCachedDeviceRegistration(
    String borrowerAccountId,
    DeviceResponse device,
  ) async {
    final key = _deviceKey(borrowerAccountId);
    final rawJson = jsonEncode(device.toJson());
    await _storage.write(key: key, value: rawJson);
  }

  Future<void> clearAllCachedProfile() async {
    try {
      final allKeys = await _storage.readAll();
      for (final key in allKeys.keys) {
        if (key.startsWith('cached_profile_') ||
            key.startsWith('cached_device_')) {
          await _storage.delete(key: key);
        }
      }
    } catch (_) {}
  }
}
