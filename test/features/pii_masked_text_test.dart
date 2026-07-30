import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/utils/formatters.dart';
import 'package:lending_nelson/features/borrowers/widgets/pii_masked_text.dart';

void main() {
  group('Formatters & PII Masking Tests', () {
    test('formatCurrency handles thousand separators correctly', () {
      expect(formatCurrency('467000.28'), '₱467,000.28');
      expect(formatCurrency('1000.00'), '₱1,000.00');
      expect(formatCurrency('0.00'), '₱0.00');
      expect(formatCurrency('-500.00'), '-₱500.00');
    });

    testWidgets(
      'PIIMaskedText masks by default and toggles visibility on tap',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PIIMaskedText(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: '+254712345678',
                isPhone: true,
              ),
            ),
          ),
        );

        // Verify default masked state
        expect(find.text('Phone: +254****678'), findsOneWidget);
        expect(find.text('Phone: +254712345678'), findsNothing);

        // Tap the eye icon to unmask
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        // Verify unmasked state
        expect(find.text('Phone: +254712345678'), findsOneWidget);
        expect(find.text('Phone: +254****678'), findsNothing);

        // Tap again to re-mask
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        // Verify re-masked state
        expect(find.text('Phone: +254****678'), findsOneWidget);
      },
    );
  });
}
