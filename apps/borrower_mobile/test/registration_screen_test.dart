import 'package:borrower_mobile/features/registration/registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registration form exposes required consent and validation',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RegistrationScreen())),
    );

    expect(find.text('Create account'), findsOneWidget);
    expect(find.byTooltip('Back to login'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'National ID'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('I accept the privacy notice'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('I accept the privacy notice'), findsOneWidget);
    expect(find.text('I accept the terms'), findsOneWidget);

    await tester.ensureVisible(find.text('Submit for review'));
    await tester.tap(find.text('Submit for review'));
    await tester.pump();

    expect(find.text('Date of birth is required'), findsOneWidget);
    expect(find.text('Please complete all required fields.'), findsOneWidget);
  });
}
