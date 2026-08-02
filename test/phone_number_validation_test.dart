import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/validation/phone_number.dart';
import 'package:lending_nelson/features/borrowers/widgets/borrower_form_fields.dart';

void main() {
  test('equivalent Philippine phone formats normalize identically', () {
    const formats = [
      '09916084400',
      '+639916084400',
      '639916084400',
      '9916084400',
      '+63 (991) 608-4400',
    ];

    expect(formats.map(normalizePhilippineMobileNumber).toSet(), {
      '+639916084400',
    });
  });

  test('borrower form rejects malformed phone numbers', () {
    expect(validatePhone('1234567'), 'Enter a valid Philippine mobile number');
    expect(validatePhone('09916084400'), isNull);
  });
}
