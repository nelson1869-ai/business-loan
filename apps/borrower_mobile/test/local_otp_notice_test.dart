import 'package:borrower_mobile/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local borrower OTP is disabled unless explicitly compiled in', () {
    expect(EnvConfig.localBorrowerOtpEnabled, isFalse);
  });
}
