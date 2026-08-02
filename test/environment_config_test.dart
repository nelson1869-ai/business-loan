import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/config/environment_config.dart';

void main() {
  group('production configuration', () {
    test('accepts a hardened HTTPS configuration', () {
      expect(
        () => EnvironmentConfig.validate(
          environment: 'production',
          apiUrl: 'https://api.lender.example',
          localOtpEnabled: false,
          debugLogging: false,
          releaseMode: true,
        ),
        returnsNormally,
      );
    });

    test('rejects local OTP, debug logging, and localhost', () {
      for (final configuration in [
        (true, false, 'https://api.lender.example'),
        (false, true, 'https://api.lender.example'),
        (false, false, 'http://10.0.2.2:8000'),
      ]) {
        expect(
          () => EnvironmentConfig.validate(
            environment: 'production',
            apiUrl: configuration.$3,
            localOtpEnabled: configuration.$1,
            debugLogging: configuration.$2,
            releaseMode: true,
          ),
          throwsStateError,
        );
      }
    });
  });
}
