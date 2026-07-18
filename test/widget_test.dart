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

    // Let the GoRouter transition settle
    await tester.pumpAndSettle();

    // Verify that the title 'Lending Nelson' is rendered on the screen
    expect(find.text('Lending Nelson'), findsOneWidget);
    expect(find.text('Mobile Client Platform'), findsOneWidget);

    // Verify that our modern icon is present
    expect(find.byIcon(Icons.account_balance), findsOneWidget);
  });
}
