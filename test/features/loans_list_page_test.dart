import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lending_nelson/features/loans/domain/models/loan.dart';
import 'package:lending_nelson/features/loans/presentation/loans_list_page.dart';
import 'package:lending_nelson/features/loans/presentation/providers/loans_provider.dart';

LoanWithBorrower _loan(String id, String borrowerName, String status) {
  return LoanWithBorrower(
    borrowerName: borrowerName,
    loan: Loan(
      id: id,
      requestId: 'request-$id',
      borrowerId: 'borrower-$id',
      createdByUserId: 'officer-1',
      originalPrincipal: '1000.00',
      outstandingPrincipal: status == 'Paid' ? '0.00' : '1000.00',
      monthlyRate: '10.00000000',
      termMonths: 1,
      paymentsPerMonth: 1,
      numberOfPayments: 1,
      regularPaymentAmount: '1100.00',
      calculationMethod: 'fixed_periodic_reducing_balance',
      startDate: '2026-07-01',
      firstDueDate: '2026-08-01',
      finalDueDate: '2026-08-01',
      status: status,
      createdAt: '2026-07-01T00:00:00Z',
    ),
  );
}

Widget _app(List<LoanWithBorrower> loans) {
  final router = GoRouter(
    initialLocation: '/loans',
    routes: [GoRoute(path: '/loans', builder: (_, _) => const LoansListPage())],
  );

  return ProviderScope(
    overrides: [allLoansProvider.overrideWith((ref) async => loans)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows all status tabs and the loan search field', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search by Borrower or Loan ID'), findsOneWidget);
  });

  testWidgets('Paid tab displays only paid loans', (tester) async {
    await tester.pumpWidget(
      _app([
        _loan('active-loan', 'Active Borrower', 'Active'),
        _loan('paid-loan', 'Paid Borrower', 'Paid'),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text('Paid')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paid Borrower'), findsOneWidget);
    expect(find.text('Active Borrower'), findsNothing);
  });

  testWidgets('Paid tab shows its empty state when no paid loans exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([_loan('active-loan', 'Active Borrower', 'Active')]),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text('Paid')),
    );
    await tester.pumpAndSettle();

    expect(find.text('No paid loans.'), findsOneWidget);
  });
}
