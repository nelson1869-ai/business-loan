import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure token storage interface for borrower client application.
class SecureTokenStorage {
  final FlutterSecureStorage _storage;

  static const _keyAccessToken = 'borrower_access_token';
  static const _keyRefreshToken = 'borrower_refresh_token';
  static const _keyBorrowerAccountId = 'borrower_account_id';
  static const _keyBorrowerId = 'borrower_id';

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

  Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyBorrowerAccountId);
    await _storage.delete(key: _keyBorrowerId);
  }
}
