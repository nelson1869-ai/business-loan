import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/borrowers/domain/borrower_model.dart';
import 'package:lending_nelson/features/borrowers/pages/borrower_registration_page.dart';
import 'package:lending_nelson/features/loans/presentation/providers/loans_provider.dart';

void main() {
  const borrower = Borrower(
    id: '00000000-0000-4000-8000-000000000001',
    firstName: 'John',
    lastName: 'Doe',
    nationalId: '12345678',
    phone: '+254712345678',
    dateOfBirth: '1990-05-15',
    status: 'Synced',
    createdAt: '2026-07-10T10:00:00.000Z',
  );

  Future<void> showForm(WidgetTester tester, {Borrower? existing}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (existing != null)
            borrowerLoansProvider(existing.id).overrideWith((ref) => const []),
        ],
        child: MaterialApp(home: BorrowerRegistrationPage(borrower: existing)),
      ),
    );
  }

  testWidgets('new borrower form uses registration labels', (tester) async {
    await showForm(tester);

    expect(find.text('Add Borrower Record'), findsNWidgets(2));
    expect(find.text('Save Changes'), findsNothing);
  });

  testWidgets('edit borrower form uses edit labels', (tester) async {
    await showForm(tester, existing: borrower);

    expect(find.text('Edit Borrower'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Add Borrower Record'), findsNothing);
    await tester.pump();
    expect(find.text('Loans'), findsOneWidget);
  });
}
