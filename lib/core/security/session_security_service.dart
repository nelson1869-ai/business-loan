import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../network/api_client.dart';

/// Securely persisted device security preferences.
class SessionSecurityService {
  SessionSecurityService(this._storage, this._localAuth);

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _biometricEnabledKey = 'security.biometric_enabled';
  static const _lastActiveKey = 'security.last_active_at';
  static const _idleMinutesKey = 'security.idle_minutes';

  /// Returns whether biometric re-authentication is enabled.
  Future<bool> isBiometricEnabled() async {
    return await _storage.read(key: _biometricEnabledKey) == 'true';
  }

  /// Enables biometrics only after a successful device authentication.
  Future<bool> setBiometricEnabled(bool enabled) async {
    if (enabled && !await authenticate()) return false;
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
    return true;
  }

  /// Uses Android biometric/device credentials without exposing secrets.
  Future<bool> authenticate() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      return await _localAuth.authenticate(
        localizedReason: 'Unlock Lending Nelson',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }

  /// Records activity for background-lock and idle-timeout decisions.
  Future<void> recordActivity() {
    return _storage.write(
      key: _lastActiveKey,
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Returns true when the securely configured idle limit has elapsed.
  Future<bool> isSessionIdle() async {
    final value = await _storage.read(key: _lastActiveKey);
    final lastActive = value == null ? null : DateTime.tryParse(value);
    final minutes =
        int.tryParse(await _storage.read(key: _idleMinutesKey) ?? '') ?? 15;
    return lastActive != null &&
        DateTime.now().toUtc().difference(lastActive) >
            Duration(minutes: minutes);
  }
}

final sessionSecurityServiceProvider = Provider<SessionSecurityService>((ref) {
  return SessionSecurityService(
    ref.watch(secureStorageProvider),
    LocalAuthentication(),
  );
});
