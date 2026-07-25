import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/loans/domain/models/payment.dart';
import 'package:lending_nelson/features/loans/presentation/payment_screen.dart';
import 'package:lending_nelson/features/loans/presentation/providers/loans_provider.dart';

void main() {
  testWidgets('reversal date picker closes without lifecycle assertion', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          loanPaymentsProvider(
            'loan-1',
          ).overrideWith((ref) async => <LoanPayment>[_payment()]),
        ],
        child: const MaterialApp(home: PaymentScreen(loanId: 'loan-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SafeArea), findsWidgets);
    final paymentList = tester.widget<ListView>(find.byType(ListView).first);
    expect(
      paymentList.keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );

    await tester.tap(find.text('\$500.00'));
    await tester.pumpAndSettle();
    final reverseButton = find.text('Reverse Payment');
    await tester.ensureVisible(reverseButton);
    await tester.pumpAndSettle();
    await tester.tap(reverseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Financial reversal date'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    expect(find.text('Reverse payment?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

LoanPayment _payment() => const LoanPayment(
  id: 'payment-1',
  requestId: '00000000-0000-4000-8000-000000000099',
  loanId: 'loan-1',
  installmentId: 'installment-1',
  entryType: 'Payment',
  reversalOfPaymentId: null,
  amount: '500.00',
  effectiveDate: '2026-07-01',
  note: 'Test payment',
  createdAt: '2026-07-01T10:00:00Z',
  allocation: PaymentAllocation(
    appliedInterest: '100.00',
    appliedPrincipal: '400.00',
    unappliedCredit: '0.00',
    interestAfter: '0.00',
    principalAfter: '600.00',
    overdueDays: 0,
  ),
);
