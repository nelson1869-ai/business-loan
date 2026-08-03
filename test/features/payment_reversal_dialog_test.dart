import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/loans/presentation/widgets/payment_reversal_dialog.dart';

void main() {
  testWidgets('reversal date picker closes without lifecycle assertion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    PaymentReversalDialog(paymentDate: DateTime(2026, 7)),
              ),
              child: const Text('Open reversal'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open reversal'));
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
