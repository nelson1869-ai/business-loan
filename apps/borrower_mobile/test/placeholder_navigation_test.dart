import 'package:borrower_mobile/core/widgets/placeholder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final destination in const [
    ('payments', 'Payments', Icons.payment_outlined),
    ('notifications', 'Notifications', Icons.notifications_none_outlined),
    ('profile', 'Profile', Icons.person_outline),
  ]) {
    testWidgets('${destination.$2} back returns to dashboard', (tester) async {
      final router = GoRouter(
        initialLocation: '/${destination.$1}',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('Dashboard Home')),
          ),
          GoRoute(
            path: '/${destination.$1}',
            builder: (_, __) => PlaceholderScreen(
              title: destination.$2,
              icon: destination.$3,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard Home'), findsOneWidget);
    });
  }
}
