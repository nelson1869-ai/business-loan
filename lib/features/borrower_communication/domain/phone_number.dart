/// Validated Philippine mobile number suitable for an SMS URI.
class PhilippinePhoneNumber {
  const PhilippinePhoneNumber._(this.e164);

  final String e164;

  /// Normalizes common Philippine mobile formats without guessing digits.
  static PhilippinePhoneNumber? tryParse(String input) {
    final compact = input.trim().replaceAll(RegExp(r'[\s()-]'), '');
    final normalized = switch (compact) {
      final value when RegExp(r'^09\d{9}$').hasMatch(value) =>
        '+63${value.substring(1)}',
      final value when RegExp(r'^639\d{9}$').hasMatch(value) => '+$value',
      final value when RegExp(r'^\+639\d{9}$').hasMatch(value) => value,
      _ => null,
    };
    return normalized == null ? null : PhilippinePhoneNumber._(normalized);
  }

  /// Masked UI label. The full value is used only for the SMS launch.
  String get masked => '${e164.substring(0, 3)} ••• ••• ${e164.substring(9)}';
}
