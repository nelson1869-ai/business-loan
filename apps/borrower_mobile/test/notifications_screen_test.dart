import 'package:borrower_mobile/features/notifications/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not fabricate borrower notification events',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: NotificationsScreen()),
      ),
    );

    expect(find.text('No notifications available'), findsOneWidget);
    expect(find.text('Borrower Account Active'), findsNothing);
    expect(find.text('Push Alerts Enabled'), findsNothing);
  });
}
