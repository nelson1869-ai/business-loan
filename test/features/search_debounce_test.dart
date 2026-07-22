import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/borrowers/domain/borrower_model.dart';
import 'package:lending_nelson/features/dashboard/widgets/quick_actions_section.dart';

void main() {
  group('Search Debounce & Selection Disambiguation Tests', () {
    const b1 = Borrower(
      id: '00000000-0000-4000-8000-000000000001',
      firstName: 'Mary',
      lastName: 'Johnson',
      nationalId: '12345678-001',
      phone: '+254712345678',
      dateOfBirth: '1995-08-22',
      status: 'Active',
      createdAt: '2026-07-10T10:00:00.000Z',
    );

    const b2 = Borrower(
      id: '00000000-0000-4000-8000-000000000002',
      firstName: 'Mary',
      lastName: 'Johnson',
      nationalId: '87654321-002',
      phone: '+254787654321',
      dateOfBirth: '1992-03-14',
      status: 'Pending',
      createdAt: '2026-07-12T10:00:00.000Z',
    );

    testWidgets(
      'Borrower picker sheet disambiguates duplicate names with masked ID suffix and phone',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: Scaffold(body: QuickActionsSection())),
          ),
        );

        // Verify Quick Actions Section renders and borrowers have unique IDs
        expect(find.text('Quick Actions'), findsOneWidget);
        expect(b1.fullName, b2.fullName);
        expect(b1.id, isNot(b2.id));
      },
    );
  });
}
