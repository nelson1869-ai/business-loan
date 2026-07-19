import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service responsible for encrypting and decrypting Personally Identifiable Information (PII).
///
/// It utilizes [FlutterSecureStorage] to persist the secret key and uses AES algorithm in CBC mode
/// to perform secure operations.
///
/// File: `lib/core/security/encryption_service.dart`
///
/// Data Flow Diagram:
/// ```text
///  +--------------------------+     +-------------------------+
///  | borrower_repository.dart | --> | encryption_service.dart |
///  +--------------------------+     +------------+------------+
///                                                |
///                                                v
///                                      Flutter Secure Storage
/// ```
class EncryptionService {
  final FlutterSecureStorage _secureStorage;
  static const _keyAlias = 'db_encryption_key';
  final Random _secureRandom = Random.secure();
  encrypt_lib.Key? _cachedKey;

  EncryptionService(this._secureStorage);

  /// Retrieves the existing encryption key or generates a new 256-bit key.
  Future<encrypt_lib.Key> _getOrGenerateKey() async {
    // Return the cached key if already loaded in memory to avoid reading from disk repeatedly
    if (_cachedKey != null) return _cachedKey!;

    // Attempt to read the key stored in Secure Storage
    String? base64Key = await _secureStorage.read(key: _keyAlias);

    // If no key exists, generate a cryptographically secure 256-bit random key
    if (base64Key == null) {
      base64Key = base64Encode(_randomBytes(32));

      // Save it securely on the device
      await _secureStorage.write(key: _keyAlias, value: base64Key);
    }

    // Cache and return the generated or loaded key
    _cachedKey = encrypt_lib.Key.fromBase64(base64Key);
    return _cachedKey!;
  }

  /// Encrypts plain text using AES/CBC with a random Initialization Vector (IV).
  ///
  /// Returns a formatted string `[IV_base64]:[ciphertext_base64]`.
  Future<String> encrypt(String plainText) async {
    if (plainText.isEmpty) return plainText;
    final key = await _getOrGenerateKey();

    // Generate a new random 16-byte initialization vector (IV) for uniqueness
    final iv = encrypt_lib.IV.fromBase64(base64Encode(_randomBytes(16)));

    // Setup AES encrypter in Cipher Block Chaining (CBC) mode
    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc),
    );

    // Perform encryption
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Combine the base64-encoded IV and the base64-encoded ciphertext with a colon
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts a formatted cipher text string `[IV_base64]:[ciphertext_base64]`.
  Future<String> decrypt(String cipherTextWithIv) async {
    if (cipherTextWithIv.isEmpty) return cipherTextWithIv;
    final key = await _getOrGenerateKey();

    // Separate the IV prefix and ciphertext suffix
    final parts = cipherTextWithIv.split(':');
    if (parts.length != 2 || parts.any((part) => part.isEmpty)) {
      throw const FormatException('Invalid encrypted value format');
    }

    // Reconstruct IV and Encrypted payloads from base64
    final iv = encrypt_lib.IV.fromBase64(parts[0]);
    final cipherText = parts[1];

    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc),
    );

    // Decrypt the cipher text back into readable text
    return encrypter.decrypt(
      encrypt_lib.Encrypted.fromBase64(cipherText),
      iv: iv,
    );
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _secureRandom.nextInt(256));
  }
}

/// Provider that exposes a singleton instance of [EncryptionService].
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService(const FlutterSecureStorage());
});
