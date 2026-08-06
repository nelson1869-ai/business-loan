import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:borrower_mobile/features/authentication/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders header and PIN login fields',
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
    expect(find.text('PIN / Password'), findsOneWidget);
    expect(find.text('Log In to Borrower Portal'), findsOneWidget);
    expect(find.text('Enter Activation Code'), findsOneWidget);
  });
}
