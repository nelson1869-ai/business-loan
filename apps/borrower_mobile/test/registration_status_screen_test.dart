import 'package:borrower_mobile/features/registration/registration_notifier.dart';
import 'package:borrower_mobile/features/registration/registration_status_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRegistrationNotifier extends StateNotifier<RegistrationState>
    implements RegistrationNotifier {
  FakeRegistrationNotifier(super.initial);

  @override
  Future<void> refresh() async {}

  @override
  Future<bool> submit(Map<String, dynamic> form) async => true;
}

void main() {
  testWidgets('approved status displays Registration Approved and Activate Account',
      (tester) async {
    final notifier = FakeRegistrationNotifier(
      const RegistrationState(
        status: 'approved',
        message: 'Your registration is approved. Use your activation code to activate your account.',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          registrationProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: RegistrationStatusScreen()),
      ),
    );

    expect(find.text('Registration Approved'), findsOneWidget);
    expect(find.text('Activate Account'), findsOneWidget);
    expect(find.text('Go to Login'), findsNothing);
  });

  testWidgets('active status displays Account Active and Go to Login',
      (tester) async {
    final notifier = FakeRegistrationNotifier(
      const RegistrationState(
        status: 'active',
        message: 'Your account is activated and ready for login.',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          registrationProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: RegistrationStatusScreen()),
      ),
    );

    expect(find.text('Account Active'), findsOneWidget);
    expect(find.text('Go to Login'), findsOneWidget);
    expect(find.text('Activate Account'), findsNothing);
  });
}
