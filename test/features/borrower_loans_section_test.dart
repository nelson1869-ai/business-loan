import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lending_nelson/features/dashboard/domain/models/borrower.dart';
import 'package:lending_nelson/features/loans/domain/models/loan.dart';
import 'package:lending_nelson/features/loans/presentation/borrower_loans_section.dart';
import 'package:lending_nelson/features/loans/presentation/providers/loans_provider.dart';

void main() {
  const borrower = Borrower(
    id: 'borrower-1',
    firstName: 'Jane',
    lastName: 'Doe',
    nationalId: '12345678',
    phone: '+254712345678',
    dateOfBirth: '1990-01-01',
    status: 'Active',
    createdAt: '2026-01-01T00:00:00Z',
  );

  testWidgets('shows borrower loans and opens the selected loan route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/borrower',
      routes: <RouteBase>[
        GoRoute(
          path: '/borrower',
          builder: (context, state) =>
              const Scaffold(body: BorrowerLoansSection(borrower: borrower)),
        ),
        GoRoute(
          path: '/loans/:loanId',
          builder: (context, state) =>
              Scaffold(body: Text('Opened ${state.pathParameters['loanId']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          borrowerLoansProvider(
            borrower.id,
          ).overrideWith((ref) => <Loan>[_loan()]),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Loans'), findsOneWidget);
    expect(find.text('Principal 1000.00'), findsOneWidget);
    expect(find.textContaining('10 payments'), findsOneWidget);

    await tester.tap(find.text('Principal 1000.00'));
    await tester.pumpAndSettle();
    expect(find.text('Opened loan-1'), findsOneWidget);
  });
}

Loan _loan() => Loan(
  id: 'loan-1',
  requestId: '00000000-0000-4000-8000-000000000002',
  borrowerId: 'borrower-1',
  createdByUserId: 'user-1',
  originalPrincipal: '1000.00',
  outstandingPrincipal: '1000.00',
  monthlyRate: '0.10',
  termMonths: 5,
  paymentsPerMonth: 2,
  numberOfPayments: 10,
  regularPaymentAmount: '129.50',
  calculationMethod: 'fixed_periodic_reducing_balance',
  startDate: '2026-08-01',
  firstDueDate: '2026-08-05',
  finalDueDate: '2026-12-20',
  status: 'Active',
  createdAt: '2026-08-01T00:00:00Z',
);
