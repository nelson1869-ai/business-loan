String normalizePhilippineMobileNumber(String rawPhone) {
  final cleaned = rawPhone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
  if (RegExp(r'^09\d{9}$').hasMatch(cleaned)) {
    return '+63${cleaned.substring(1)}';
  }
  if (RegExp(r'^639\d{9}$').hasMatch(cleaned)) {
    return '+$cleaned';
  }
  if (RegExp(r'^9\d{9}$').hasMatch(cleaned)) {
    return '+63$cleaned';
  }
  if (RegExp(r'^6309\d{9}$').hasMatch(cleaned)) {
    return '+63${cleaned.substring(3)}';
  }
  throw const FormatException('Invalid Philippine mobile number');
}
