import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/loans/domain/models/installment.dart';
import 'package:lending_nelson/features/loans/domain/models/loan.dart';
import 'package:lending_nelson/features/loans/presentation/loan_create_screen.dart';
import 'package:lending_nelson/features/loans/presentation/loan_detail_screen.dart';
import 'package:lending_nelson/features/loans/presentation/providers/loans_provider.dart';

void main() {
  test('percentage conversion stays exact without binary floating point', () {
    expect(percentageToDecimalRate('10'), '0.1');
    expect(percentageToDecimalRate('10.5'), '0.105');
    expect(percentageToDecimalRate('0.125'), '0.00125');
  });

  testWidgets('create form validates required financial terms', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoanCreateScreen(borrowerId: 'borrower-1')),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Create Loan'));
    await tester.pump();

    expect(
      find.text('Enter a positive amount with up to 2 decimal places'),
      findsOneWidget,
    );
  });

  testWidgets('detail screen renders the backend installment breakdown', (
    tester,
  ) async {
    final loan = _loan();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loanDetailProvider(loan.id).overrideWith((ref) async => loan),
        ],
        child: MaterialApp(home: LoanDetailScreen(loanId: loan.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Installment Schedule'), findsOneWidget);
    expect(find.text('Payment 1 · 129.50'), findsOneWidget);
    expect(find.text('2026-08-05 · Scheduled'), findsOneWidget);

    await tester.tap(find.text('Payment 1 · 129.50'));
    await tester.pumpAndSettle();
    expect(find.text('Interest'), findsOneWidget);
    expect(find.text('50.00'), findsOneWidget);
    expect(find.text('Remaining principal'), findsOneWidget);
    expect(find.text('920.50'), findsOneWidget);
  });
}

Loan _loan() => Loan(
  id: 'loan-1',
  borrowerId: 'borrower-1',
  createdByUserId: 'user-1',
  originalPrincipal: '1000.00',
  outstandingPrincipal: '1000.00',
  monthlyRate: '0.10000000',
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
  installments: const <Installment>[
    Installment(
      id: 'installment-1',
      loanId: 'loan-1',
      installmentNumber: 1,
      dueDate: '2026-08-05',
      expectedPayment: '129.50',
      expectedInterest: '50.00',
      expectedPrincipal: '79.50',
      expectedRemainingPrincipal: '920.50',
      paidAmount: '0.00',
      status: 'Scheduled',
      createdAt: '2026-08-01T00:00:00Z',
    ),
  ],
);
