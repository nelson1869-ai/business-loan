/// Environment configuration for borrower mobile app.
class EnvConfig {
  static const String defaultApiBaseUrl = 'http://10.0.2.2:8000';

  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return defaultApiBaseUrl;
  }

  /// Whether the local development backend accepts the fixed borrower OTP.
  static const bool localBorrowerOtpEnabled = bool.fromEnvironment(
    'LOCAL_BORROWER_OTP_ENABLED',
    defaultValue: false,
  );
}
