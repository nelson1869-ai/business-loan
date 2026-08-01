import 'package:flutter_test/flutter_test.dart';
import 'package:borrower_mobile/core/auth/auth_state.dart';

void main() {
  group('AuthState Model Tests', () {
    test('AuthState.unknown initial state', () {
      final state = AuthState.unknown();
      expect(state.status, equals(AuthStatus.unknown));
      expect(state.borrowerAccountId, isNull);
    });

    test('AuthState.authenticated sets account values', () {
      final state = AuthState.authenticated(
        borrowerAccountId: 'acct-123',
        borrowerId: 'bor-456',
      );
      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.borrowerAccountId, equals('acct-123'));
      expect(state.borrowerId, equals('bor-456'));
    });

    test('AuthState copyWith preserves untouched fields', () {
      final initial = AuthState.authenticated(
        borrowerAccountId: 'acct-123',
        borrowerId: 'bor-456',
      );
      final updated = initial.copyWith(resendCooldownSeconds: 45);
      expect(updated.borrowerAccountId, equals('acct-123'));
      expect(updated.resendCooldownSeconds, equals(45));
    });
  });
}
