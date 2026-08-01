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
    expect(find.text('Borrower Portal'), findsOneWidget);
    expect(find.text('Mobile Number'), findsOneWidget);
    expect(find.text('Request OTP Code'), findsOneWidget);
  });
}
