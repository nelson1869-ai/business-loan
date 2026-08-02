import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:borrower_mobile/features/authentication/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders header and input fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    expect(find.text('Lending Nelson'), findsOneWidget);
    expect(find.text('BORROWER PORTAL'), findsOneWidget);
    expect(find.text('Mobile Number'), findsOneWidget);
    expect(find.text('Request OTP Code'), findsOneWidget);
    expect(find.byKey(const Key('local-development-otp-notice')), findsNothing);
  });

  testWidgets('LoginScreen visibly identifies the fixed local OTP',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(localOtpEnabled: true),
        ),
      ),
    );

    expect(
      find.byKey(const Key('local-development-otp-notice')),
      findsOneWidget,
    );
    expect(find.text('Local development only: use OTP 123456'), findsOneWidget);
  });
}
