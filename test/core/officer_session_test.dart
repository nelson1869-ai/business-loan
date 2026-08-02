import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/security/officer_session.dart';

void main() {
  test('parses officer identity and exact backend permission hints', () {
    final token = _token({
      'sub': 'user-1',
      'username': 'cashier',
      'role': 'cashier',
    });
    final session = OfficerSession.fromAccessToken(token);
    expect(session?.userId, 'user-1');
    expect(session?.can('accounting.view'), isTrue);
    expect(session?.can('policy.approve'), isFalse);
  });

  test('rejects malformed access-token payloads', () {
    expect(OfficerSession.fromAccessToken('invalid'), isNull);
    expect(OfficerSession.fromAccessToken(_token({'sub': 'user-1'})), isNull);
  });
}

String _token(Map<String, dynamic> payload) {
  final encoded = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  return 'header.$encoded.signature';
}
