import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/app/app.dart';

void main() {
  testWidgets('App starts and renders welcome screen', (
    WidgetTester tester,
  ) async {
    // Build our app under ProviderScope and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: LendingNelsonApp()));

    // Verify that the splash screen elements are rendered
    expect(find.text('Lending Nelson'), findsOneWidget);
    expect(find.text('Secure Mobile Lending'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance), findsOneWidget);

    // Wait for the redirect timer to run
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    // Verify that it transitioned to the login screen
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
