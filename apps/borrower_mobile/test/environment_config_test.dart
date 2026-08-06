import 'package:borrower_mobile/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('borrower production accepts only hardened configuration', () {
    expect(
      () => EnvConfig.validate(
        environment: 'production',
        apiUrl: 'https://api.lender.example',
        debugLogging: false,
        releaseMode: true,
      ),
      returnsNormally,
    );
    expect(
      () => EnvConfig.validate(
        environment: 'production',
        apiUrl: 'http://localhost:8000',
        debugLogging: true,
        releaseMode: true,
      ),
      throwsStateError,
    );
  });
}
