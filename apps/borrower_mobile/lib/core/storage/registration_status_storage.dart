import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely retains only the opaque registration status capability token.
class RegistrationStatusStorage {
  RegistrationStatusStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'borrower_registration_token';
  final FlutterSecureStorage _storage;

  Future<void> save(String token) => _storage.write(key: _key, value: token);
  Future<String?> read() => _storage.read(key: _key);
  Future<void> clear() => _storage.delete(key: _key);
}
