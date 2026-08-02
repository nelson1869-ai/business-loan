import 'package:flutter/foundation.dart';

/// Compile-time environment configuration and release safety validation.
class EnvironmentConfig {
  const EnvironmentConfig._();

  static const String appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const bool localBorrowerOtpEnabled = bool.fromEnvironment(
    'LOCAL_BORROWER_OTP_ENABLED',
    defaultValue: false,
  );
  static const bool debugLoggingEnabled = bool.fromEnvironment(
    'DEBUG_LOGGING_ENABLED',
    defaultValue: false,
  );

  static void validateForStartup() {
    validate(
      environment: appEnvironment,
      apiUrl: apiBaseUrl,
      localOtpEnabled: localBorrowerOtpEnabled,
      debugLogging: debugLoggingEnabled,
      releaseMode: kReleaseMode,
    );
  }

  @visibleForTesting
  static void validate({
    required String environment,
    required String apiUrl,
    required bool localOtpEnabled,
    required bool debugLogging,
    required bool releaseMode,
  }) {
    if (!releaseMode) return;
    final uri = Uri.tryParse(apiUrl);
    if (environment == 'production') {
      if (localOtpEnabled) {
        throw StateError('Development OTP cannot be enabled in production.');
      }
      if (debugLogging) {
        throw StateError('Debug logging cannot be enabled in production.');
      }
      if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
        throw StateError('Production API_BASE_URL must be an absolute HTTPS URL.');
      }
      if (_isLocalHost(uri.host)) {
        throw StateError('Production API_BASE_URL cannot point to localhost.');
      }
    }
  }

  static bool _isLocalHost(String host) =>
      host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '10.0.2.2' ||
      host == '::1';
}
