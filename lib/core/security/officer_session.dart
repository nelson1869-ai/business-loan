import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Non-authoritative session hints used only to hide unavailable UI actions.
///
/// Every request is still authorized by the backend. JWT signatures are not
/// validated on-device because this parser never grants server access.
class OwnerSession {
  const OwnerSession({
    required this.userId,
    required this.username,
    required this.role,
  });

  final String userId;
  final String username;
  final String role;

  Set<String> get permissions => _rolePermissions[role] ?? const {};

  bool can(String permission) => permissions.contains(permission);

  static OwnerSession? fromAccessToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return null;
      final claims = Map<String, dynamic>.from(payload);
      final userId = claims['sub'] as String?;
      final username = claims['username'] as String?;
      final role = claims['role'] as String?;
      if (userId == null || username == null || role == null) return null;
      return OwnerSession(userId: userId, username: username, role: role);
    } on FormatException {
      return null;
    }
  }
}

const _allPermissions = <String>{
  'borrower.create',
  'borrower.update',
  'borrower.archive',
  'loan.create',
  'loan.approve',
  'loan.disburse',
  'loan.restructure',
  'loan.write_off',
  'payment.reverse',
  'payment.collect',
  'accounting.view',
  'accounting.post_adjustment',
  'policy.create',
  'policy.approve',
  'reconciliation.submit',
  'reconciliation.approve',
  'report.view',
  'audit.view',
  'borrower_registration.review',
  'borrower_account.manage',
};

const _rolePermissions = <String, Set<String>>{
  'admin': _allPermissions,
  'owner': _allPermissions,
  'manager': _allPermissions,
  'officer': {
    'borrower.create',
    'borrower.update',
    'loan.create',
    'payment.collect',
    'reconciliation.submit',
    'report.view',
  },
  'loan_officer': {
    'borrower.create',
    'borrower.update',
    'loan.create',
    'payment.collect',
    'report.view',
  },
  'collector': {'payment.collect', 'reconciliation.submit'},
  'cashier': {
    'reconciliation.submit',
    'reconciliation.approve',
    'accounting.view',
    'report.view',
  },
  'auditor': {'accounting.view', 'report.view', 'audit.view'},
  'read_only_support': {'report.view'},
};

/// Current owner identity and UI permission hints read from secure storage.
final ownerSessionProvider = FutureProvider.autoDispose<OwnerSession?>((
  ref,
) async {
  final token = await ref
      .watch(secureStorageProvider)
      .read(key: TokenStorageKeys.accessToken);
  return token == null ? null : OwnerSession.fromAccessToken(token);
});
