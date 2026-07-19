// Flutter and Testing packages
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// App Core Services
import 'package:lending_nelson/app/app.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/core/security/encryption_service.dart';

// Feature Repository & Models
import 'package:lending_nelson/features/dashboard/data/repositories/borrower_repository.dart';
import 'package:lending_nelson/features/dashboard/domain/models/borrower.dart';

/// A mock borrower repository for widget tests to avoid FFI database issues.
class FakeBorrowerRepository extends BorrowerRepository {
  final List<Borrower> _borrowers = [];

  FakeBorrowerRepository()
    : super(DatabaseService(), EncryptionService(const FlutterSecureStorage()));

  @override
  Future<void> saveBorrower(Borrower borrower) async {
    _borrowers.add(borrower);
  }

  @override
  Future<List<Borrower>> getBorrowers() async {
    return List.from(_borrowers);
  }
}

void main() {
  group('App Navigation & Flows Integration Widget Tests', () {
    testWidgets(
      'App starts with Splash, redirects to Login, and logs in successfully',
      (WidgetTester tester) async {
        // 1. Launch the app with the FakeBorrowerRepository override
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              borrowerRepositoryProvider.overrideWithValue(
                FakeBorrowerRepository(),
              ),
            ],
            child: const LendingNelsonApp(),
          ),
        );

        // Verify Splash Screen renders
        expect(find.text('Secure Mobile Lending'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // 2. Wait for Splash delay (1.5 seconds) to trigger routing to Login Screen
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();

        // Verify Login Screen renders
        expect(find.text('Welcome Back'), findsOneWidget);
        expect(find.text('Username'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);

        // 3. Verify the debug-only classroom credentials are prefilled.
        final fields = tester.widgetList<TextFormField>(
          find.byType(TextFormField),
        );
        expect(fields.elementAt(0).controller?.text, 'officer1');
        expect(fields.elementAt(1).controller?.text, 'password123');

        // 4. Continue with the prefilled development login.
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
        await tester.pumpAndSettle();

        // Verify Dashboard Screen renders
        expect(find.text('Portfolio Summary'), findsOneWidget);
        expect(find.text('Welcome, Officer!'), findsOneWidget);

        // 5. Test Bottom Navigation: Switch to Borrowers Tab
        await tester.tap(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.byIcon(Icons.people),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Borrower List Screen renders
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Borrowers'),
          ),
          findsOneWidget,
        );
        expect(find.text('John Doe'), findsOneWidget);

        // 6. Test subroute navigation: Open Register Borrower Screen
        final fabFinder = find.byType(FloatingActionButton);
        expect(fabFinder, findsOneWidget);
        final fab = tester.widget<FloatingActionButton>(fabFinder);
        fab.onPressed!();
        await tester.pumpAndSettle();

        // Verify Register Borrower Screen renders
        expect(find.text('Register Borrower'), findsOneWidget);
        expect(
          find.widgetWithText(TextFormField, 'First Name'),
          findsOneWidget,
        );

        // Go back to Borrower List
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Borrowers'),
          ),
          findsOneWidget,
        );

        // 7. Test Bottom Navigation: Switch to Settings Tab
        await tester.tap(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.byIcon(Icons.settings),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Settings Screen renders
        expect(find.text('Officer Profile'), findsOneWidget);
        expect(find.text('Assigned Branch'), findsOneWidget);

        // 8. Test Logout Action
        await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
        await tester.pumpAndSettle();

        // Verify redirected back to Login Screen
        expect(find.text('Welcome Back'), findsOneWidget);
      },
    );
  });
}
