import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/borrower_registrations/presentation/borrower_registration_requests_page.dart';

void main() {
  testWidgets('admin queue shows masked pending registration', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendingRegistrationsProvider.overrideWith(
            (ref) async => [
              {
                'id': 'request-1',
                'firstName': 'Maria',
                'lastName': 'Santos',
                'maskedPhone': '+63•••••567',
                'submittedAt': '2026-08-03T10:00:00Z',
                'dateOfBirth': '1990-01-01',
              },
            ],
          ),
        ],
        child: const MaterialApp(home: BorrowerRegistrationRequestsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending Borrower Registrations (1)'), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.textContaining('•••••'), findsOneWidget);
  });
}
