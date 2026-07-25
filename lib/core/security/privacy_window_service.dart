import 'package:flutter/services.dart';

/// Android platform security controls that do not alter authorization.
class PrivacyWindowService {
  PrivacyWindowService._();

  static const _channel = MethodChannel('com.nelson.lending/security');

  /// Prevents screenshots and recent-app previews on sensitive screens.
  static Future<void> setSecureWindow(bool enabled) async {
    await _channel.invokeMethod<void>('setSecureWindow', {'enabled': enabled});
  }

  /// Returns a warning-only rooted-device signal.
  static Future<bool> isDevicePotentiallyRooted() async {
    return await _channel.invokeMethod<bool>('isPotentiallyRooted') ?? false;
  }
}
