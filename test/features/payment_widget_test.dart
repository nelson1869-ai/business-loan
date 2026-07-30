import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lending_nelson/features/loans/domain/models/payment.dart';
import 'package:lending_nelson/features/loans/data/repositories/remote_payment_repository.dart';
import 'package:lending_nelson/features/loans/presentation/widgets/payment_form_card.dart';
import 'package:lending_nelson/features/loans/presentation/widgets/payment_preview_card.dart';
import 'package:lending_nelson/features/loans/presentation/widgets/payment_reversal_dialog.dart';

/* -------------------------------------------------------------------------- */
/*  Helpers                                                                   */
/* -------------------------------------------------------------------------- */

/// Wraps [child] in a [MaterialApp] + [ProviderScope] with a mocked payment
/// repository so that any provider depending on
/// [remotePaymentRepositoryProvider] resolves without network calls.
Widget withApp(Widget child) {
  return ProviderScope(
    overrides: [
      remotePaymentRepositoryProvider.overrideWithValue(
        RemotePaymentRepository(Dio()),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

/// Mounts [PaymentReversalDialog] inside its own [Navigator] route so that
/// `Navigator.pop` works.
Widget buildDialogInRoute({required DateTime paymentDate}) {
  return MaterialApp(
    home: Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => PaymentReversalDialog(paymentDate: paymentDate),
      ),
    ),
  );
}

/// Creates a [PaymentPreview] with non-zero values for exhaustive rendering
/// verification.
PaymentPreview _fullPreview({bool isPayoff = false}) => PaymentPreview(
  loanId: 'loan-1',
  installmentId: 'installment-1',
  paymentAmount: '150.00',
  effectiveDate: '2026-07-20',
  dueDate: '2026-07-15',
  daysEarly: 0,
  overdueDays: 5,
  accruedInterest: '30.00',
  totalInterestBefore: '100.00',
  principalBefore: '1000.00',
  appliedInterest: '25.00',
  appliedPrincipal: '125.00',
  unappliedCredit: '0.00',
  interestAfter: '75.00',
  principalAfter: '875.00',
  amountAboveScheduled: '10.00',
  nextPeriodInterest: '28.50',
  isPayoff: isPayoff,
);

PaymentPreview _earlyPreview() => PaymentPreview(
  loanId: 'loan-1',
  installmentId: 'installment-1',
  paymentAmount: '150.00',
  effectiveDate: '2026-07-10',
  dueDate: '2026-07-15',
  daysEarly: 5,
  overdueDays: 0,
  accruedInterest: '20.00',
  totalInterestBefore: '100.00',
  principalBefore: '1000.00',
  appliedInterest: '20.00',
  appliedPrincipal: '130.00',
  unappliedCredit: '5.00',
  interestAfter: '80.00',
  principalAfter: '870.00',
  amountAboveScheduled: '10.00',
  nextPeriodInterest: '28.50',
  isPayoff: false,
);

/* -------------------------------------------------------------------------- */
/*  validatePaymentAmount (pure function)                                     */
/* -------------------------------------------------------------------------- */

void main() {
  group('validatePaymentAmount', () {
    test('returns error for empty input', () {
      expect(validatePaymentAmount(''), isNotNull);
      expect(validatePaymentAmount(null), isNotNull);
    });

    test('returns error for zero values', () {
      expect(validatePaymentAmount('0'), isNotNull);
      expect(validatePaymentAmount('0.00'), isNotNull);
      expect(validatePaymentAmount('0.0'), isNotNull);
    });

    test('returns error for non-numeric input', () {
      expect(validatePaymentAmount('abc'), isNotNull);
      expect(validatePaymentAmount('12.abc'), isNotNull);
    });

    test('returns null for valid amounts', () {
      expect(validatePaymentAmount('100'), isNull);
      expect(validatePaymentAmount('100.50'), isNull);
      expect(validatePaymentAmount('0.01'), isNull);
      expect(validatePaymentAmount('999999.99'), isNull);
    });
  });

  /* -------------------------------------------------------------------------- */
  /*  PaymentFormCard                                                           */
  /* -------------------------------------------------------------------------- */

  group('PaymentFormCard', () {
    Widget buildForm({bool working = false, String? dateLabel}) {
      final formKey = GlobalKey<FormState>();
      final amountCtrl = TextEditingController();
      final noteCtrl = TextEditingController();
      return withApp(
        PaymentFormCard(
          formKey: formKey,
          amountController: amountCtrl,
          noteController: noteCtrl,
          dateLabel: dateLabel ?? '2026-07-20',
          working: working,
          theme: ThemeData(),
          onPickDate: () {},
          onPreview: () {},
          onFieldChange: () {},
        ),
      );
    }

    testWidgets('renders title and form fields', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(find.text('Record a payment'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Effective date'), findsOneWidget);
      expect(find.text('Note (optional)'), findsOneWidget);
      expect(find.text('Preview Payment'), findsOneWidget);
    });

    testWidgets('displays the provided date label', (tester) async {
      await tester.pumpWidget(buildForm(dateLabel: '2026-07-20'));
      await tester.pumpAndSettle();

      expect(find.text('2026-07-20'), findsOneWidget);
    });

    testWidgets(
      'shows validation error when preview is tapped with empty amount',
      (tester) async {
        final formKey = GlobalKey<FormState>();
        final amountCtrl = TextEditingController();
        final noteCtrl = TextEditingController();
        await tester.pumpWidget(
          withApp(
            PaymentFormCard(
              formKey: formKey,
              amountController: amountCtrl,
              noteController: noteCtrl,
              dateLabel: '2026-07-20',
              working: false,
              theme: ThemeData(),
              onPickDate: () {},
              onPreview: () => formKey.currentState!.validate(),
              onFieldChange: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Preview Payment'));
        await tester.pumpAndSettle();

        expect(
          find.text('Enter an amount greater than zero with up to 2 decimals'),
          findsOneWidget,
        );
      },
    );

    testWidgets('disables preview button when working is true', (tester) async {
      await tester.pumpWidget(buildForm(working: true));
      await tester.pumpAndSettle();

      final previewBtn = find.widgetWithText(FilledButton, 'Preview Payment');
      expect(tester.widget<FilledButton>(previewBtn).onPressed, isNull);
    });
  });

  /* -------------------------------------------------------------------------- */
  /*  PaymentPreviewCard                                                        */
  /* -------------------------------------------------------------------------- */

  group('PaymentPreviewCard', () {
    Widget buildPreview(PaymentPreview preview, {bool working = false}) {
      return withApp(
        PaymentPreviewCard(
          preview: preview,
          working: working,
          onConfirm: () {},
        ),
      );
    }

    testWidgets('renders all allocation fields for a full preview', (
      tester,
    ) async {
      await tester.pumpWidget(buildPreview(_fullPreview()));
      await tester.pumpAndSettle();

      expect(find.text('Payment preview'), findsOneWidget);
      expect(find.text('₱150.00'), findsOneWidget);
      expect(find.text('₱25.00'), findsOneWidget);
      expect(find.text('₱125.00'), findsOneWidget);
      expect(find.text('₱10.00'), findsOneWidget);
      expect(find.text('₱75.00'), findsOneWidget);
      expect(find.text('₱875.00'), findsOneWidget);
      expect(find.text('₱28.50'), findsOneWidget);
    });

    testWidgets('shows overdue indicator when overdueDays > 0', (tester) async {
      await tester.pumpWidget(buildPreview(_fullPreview()));
      await tester.pumpAndSettle();

      expect(find.textContaining('5'), findsWidgets);
      expect(find.textContaining('Days late'), findsOneWidget);
    });

    testWidgets('shows early and unapplied credit indicators', (tester) async {
      await tester.pumpWidget(buildPreview(_earlyPreview()));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      expect(find.textContaining('Days early'), findsOneWidget);
      expect(find.textContaining('Unapplied credit'), findsOneWidget);
      expect(find.text('₱5.00'), findsWidgets);
    });

    testWidgets('shows Confirm Payoff when isPayoff is true', (tester) async {
      await tester.pumpWidget(buildPreview(_fullPreview(isPayoff: true)));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Payoff'), findsOneWidget);
      expect(find.text('Confirm Payment'), findsNothing);
    });

    testWidgets('shows Confirm Payment when isPayoff is false', (tester) async {
      await tester.pumpWidget(buildPreview(_fullPreview(isPayoff: false)));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Payment'), findsOneWidget);
      expect(find.text('Confirm Payoff'), findsNothing);
    });

    testWidgets('disables confirm button when working is true', (tester) async {
      await tester.pumpWidget(buildPreview(_fullPreview(), working: true));
      await tester.pumpAndSettle();

      final btn = find.widgetWithText(FilledButton, 'Confirm Payment');
      expect(tester.widget<FilledButton>(btn).onPressed, isNull);
    });

    testWidgets('hides unapplied credit row when zero', (tester) async {
      await tester.pumpWidget(buildPreview(_fullPreview()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unapplied credit'), findsNothing);
    });
  });

  /* -------------------------------------------------------------------------- */
  /*  PaymentReversalDialog                                                     */
  /* -------------------------------------------------------------------------- */

  group('PaymentReversalDialog', () {
    testWidgets('shows dialog title and description', (tester) async {
      final paymentDate = DateTime(2026, 7, 15);
      await tester.pumpWidget(buildDialogInRoute(paymentDate: paymentDate));
      await tester.pumpAndSettle();

      expect(find.text('Reverse payment?'), findsOneWidget);
      expect(find.textContaining('original record remains'), findsOneWidget);
    });

    testWidgets('shows validation error for empty reason', (tester) async {
      await tester.pumpWidget(
        buildDialogInRoute(paymentDate: DateTime(2026, 7, 15)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reverse Payment'));
      await tester.pumpAndSettle();

      expect(find.text('Enter at least 3 characters'), findsOneWidget);
    });

    testWidgets('shows validation error for short reason', (tester) async {
      await tester.pumpWidget(
        buildDialogInRoute(paymentDate: DateTime(2026, 7, 15)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump();

      await tester.tap(find.text('Reverse Payment'));
      await tester.pumpAndSettle();

      expect(find.text('Enter at least 3 characters'), findsOneWidget);
    });

    testWidgets('clears error once user starts typing', (tester) async {
      await tester.pumpWidget(
        buildDialogInRoute(paymentDate: DateTime(2026, 7, 15)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reverse Payment'));
      await tester.pumpAndSettle();
      expect(find.text('Enter at least 3 characters'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      expect(find.text('Enter at least 3 characters'), findsNothing);
    });

    testWidgets('cancel pops the dialog', (tester) async {
      await tester.pumpWidget(
        buildDialogInRoute(paymentDate: DateTime(2026, 7, 15)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reverse payment?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Reverse payment?'), findsNothing);
    });
  });
}
