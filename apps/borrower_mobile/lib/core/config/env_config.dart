import 'package:flutter/foundation.dart';

/// Environment configuration for borrower mobile app.
class EnvConfig {
  static const String defaultApiBaseUrl =
      'https://lending-nelson-api.onrender.com';

  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      validate(
        environment: appEnvironment,
        apiUrl: fromEnv,
        debugLogging: debugLoggingEnabled,
        releaseMode: kReleaseMode,
      );
      return fromEnv;
    }
    validate(
      environment: appEnvironment,
      apiUrl: defaultApiBaseUrl,
      debugLogging: debugLoggingEnabled,
      releaseMode: kReleaseMode,
    );
    return defaultApiBaseUrl;
  }

  static const String appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
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
    required bool debugLogging,
    required bool releaseMode,
  }) {
    if (!releaseMode || environment != 'production') return;
    final uri = Uri.tryParse(apiUrl);
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
