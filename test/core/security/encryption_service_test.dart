import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/security/encryption_service.dart';

class _MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

void main() {
  late _MemorySecureStorage secureStorage;
  late EncryptionService encryptionService;

  setUp(() {
    secureStorage = _MemorySecureStorage();
    encryptionService = EncryptionService(secureStorage);
  });

  test('uses a unique random IV for each encrypted value', () async {
    final first = await encryptionService.encrypt('sensitive-value');
    final second = await encryptionService.encrypt('sensitive-value');

    expect(first, isNot(second));
    expect(await encryptionService.decrypt(first), 'sensitive-value');
    expect(await encryptionService.decrypt(second), 'sensitive-value');
  });

  test('decrypts records written with the previous zero IV', () async {
    await encryptionService.encrypt('initialize-key');
    final key = encrypt_lib.Key.fromBase64(
      secureStorage.values['db_encryption_key']!,
    );
    final iv = encrypt_lib.IV.fromLength(16);
    final encrypted = encrypt_lib.Encrypter(
      encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc),
    ).encrypt('legacy-value', iv: iv);
    final legacyValue = '${iv.base64}:${encrypted.base64}';

    expect(await encryptionService.decrypt(legacyValue), 'legacy-value');
  });

  test('passes through unencrypted plain text values gracefully', () async {
    expect(
      await encryptionService.decrypt('plain-unencrypted-text'),
      'plain-unencrypted-text',
    );
  });
}
