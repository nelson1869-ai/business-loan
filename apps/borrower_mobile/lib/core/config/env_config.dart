import 'package:flutter/foundation.dart';

/// Environment configuration for borrower mobile app.
class EnvConfig {
  static const String defaultApiBaseUrl = 'http://10.0.2.2:8000';

  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      validate(
        environment: appEnvironment,
        apiUrl: fromEnv,
        localOtpEnabled: localBorrowerOtpEnabled,
        debugLogging: debugLoggingEnabled,
        releaseMode: kReleaseMode,
      );
      return fromEnv;
    }
    validate(
      environment: appEnvironment,
      apiUrl: defaultApiBaseUrl,
      localOtpEnabled: localBorrowerOtpEnabled,
      debugLogging: debugLoggingEnabled,
      releaseMode: kReleaseMode,
    );
    return defaultApiBaseUrl;
  }

  static const String appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  /// Whether the local development backend accepts the fixed borrower OTP.
  static const bool localBorrowerOtpEnabled = bool.fromEnvironment(
    'LOCAL_BORROWER_OTP_ENABLED',
    defaultValue: false,
  );

  static const bool debugLoggingEnabled = bool.fromEnvironment(
    'DEBUG_LOGGING_ENABLED',
    defaultValue: false,
  );

  static void validateForStartup() {
    apiBaseUrl;
  }

  @visibleForTesting
  static void validate({
    required String environment,
    required String apiUrl,
    required bool localOtpEnabled,
    required bool debugLogging,
    required bool releaseMode,
  }) {
    if (!releaseMode || environment != 'production') return;
    final uri = Uri.tryParse(apiUrl);
    if (localOtpEnabled) {
      throw StateError('Development OTP cannot be enabled in production.');
    }
    if (debugLogging) {
      throw StateError('Debug logging cannot be enabled in production.');
    }
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
      throw StateError(
          'Production API_BASE_URL must be an absolute HTTPS URL.');
    }
    if ({'localhost', '127.0.0.1', '10.0.2.2', '::1'}.contains(uri.host)) {
      throw StateError('Production API_BASE_URL cannot point to localhost.');
    }
  }
}
