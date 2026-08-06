import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure token storage interface for borrower client application.
class SecureTokenStorage {
  final FlutterSecureStorage _storage;

  static const _keyAccessToken = 'borrower_access_token';
  static const _keyRefreshToken = 'borrower_refresh_token';
  static const _keyBorrowerAccountId = 'borrower_account_id';
  static const _keyBorrowerId = 'borrower_id';
  static const _keyInstallationId = 'borrower_installation_id';
  static const _keySavedPhone = 'borrower_saved_phone';

  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String borrowerAccountId,
    required String borrowerId,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
    await _storage.write(key: _keyBorrowerAccountId, value: borrowerAccountId);
    await _storage.write(key: _keyBorrowerId, value: borrowerId);
  }

  Future<String?> getAccessToken() async =>
      await _storage.read(key: _keyAccessToken);
  Future<String?> getRefreshToken() async =>
      await _storage.read(key: _keyRefreshToken);
  Future<String?> getBorrowerAccountId() async =>
      await _storage.read(key: _keyBorrowerAccountId);
  Future<String?> getBorrowerId() async =>
      await _storage.read(key: _keyBorrowerId);

  Future<String> getOrCreateInstallationId() async {
    final existing = await _storage.read(key: _keyInstallationId);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40;
    values[8] = (values[8] & 0x3f) | 0x80;
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final uuidStr =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
    await _storage.write(key: _keyInstallationId, value: uuidStr);
    return uuidStr;
  }

  Future<void> savePhone(String phone) async =>
      await _storage.write(key: _keySavedPhone, value: phone);

  Future<String?> getSavedPhone() async =>
      await _storage.read(key: _keySavedPhone);

  Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyBorrowerAccountId);
    await _storage.delete(key: _keyBorrowerId);
  }
}
