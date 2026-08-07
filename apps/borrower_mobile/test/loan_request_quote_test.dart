import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/core/api/api_error.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:borrower_mobile/features/loans/loan_request_modal.dart';

// ---------------------------------------------------------------------------
// Fake API client
// ---------------------------------------------------------------------------

class _FakeApiClient implements ApiClient {
  _FakeApiClient({required this.quoteResponse, this.shouldThrow = false});

  final Map<String, dynamic> quoteResponse;
  final bool shouldThrow;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #post) {
      final path = invocation.positionalArguments.first as String;
      if (path.contains('/loan-requests/quote')) {
        if (shouldThrow) throw const ApiError(message: 'Network error');
        return Future.value(quoteResponse);
      }
      return Future.value(<String, dynamic>{});
    }
    return super.noSuchMethod(invocation);
  }
}

class _SlowFakeApiClient implements ApiClient {
  _SlowFakeApiClient(this.futureResponse);

  final Future<Map<String, dynamic>> futureResponse;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #post) {
      return futureResponse;
    }
    return super.noSuchMethod(invocation);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _unavailableResponse = <String, dynamic>{
  'available': false,
  'message': 'Loan estimate is currently unavailable. Final terms will be provided by the lender.',
};

final _availableResponse = <String, dynamic>{
  'available': true,
  'estimatedMonthlyRate': '0.10000000',
  'disclaimer': 'Estimate only. Final interest, payment dates, fees, and approved terms are determined by the lender.',
  'numberOfPayments': 1,
  'regularPaymentAmount': '11000.00',
  'totalInterest': '1000.00',
  'totalRepayment': '11000.00',
  'provisionalFirstDueDate': '2026-09-15',
  'provisionalFinalDueDate': '2026-09-15',
  'installments': [
    {
      'installmentNumber': 1,
      'dueDate': '2026-09-15',
      'paymentAmount': '11000.00',
      'interestAmount': '1000.00',
      'principalAmount': '10000.00',
      'remainingPrincipal': '0.00',
    }
  ],
};

Widget _buildModal({required Map<String, dynamic> quoteResponse, bool shouldThrow = false}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(
        _FakeApiClient(quoteResponse: quoteResponse, shouldThrow: shouldThrow),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: LoanRequestModal(),
      ),
    ),
  );
}

Future<void> _tapButton(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder, warnIfMissed: false);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('LoanRequestModal — Calculate Estimate button', () {
    testWidgets('1. Calculate Estimate button is visible', (tester) async {
      await tester.pumpWidget(_buildModal(quoteResponse: _unavailableResponse));
      expect(find.text('Calculate Estimate'), findsOneWidget);
    });

    testWidgets('2. Tapping Calculate Estimate calls quote endpoint', (tester) async {
      final client = _FakeApiClient(quoteResponse: _availableResponse);
      await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: const MaterialApp(home: Scaffold(body: LoanRequestModal())),
      ));

      await tester.enterText(find.byType(TextFormField).first, '10000');
      await tester.pump();
      await _tapButton(tester, find.text('Calculate Estimate'));
      await tester.pumpAndSettle();
    });

    testWidgets('3. Loading indicator shown while calculating', (tester) async {
      final completer = Completer<Map<String, dynamic>>();

      final slowClient = _SlowFakeApiClient(completer.future);

      await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(slowClient)],
        child: const MaterialApp(home: Scaffold(body: LoanRequestModal())),
      ));

      await tester.enterText(find.byType(TextFormField).first, '10000');
      await tester.pump();
      await _tapButton(tester, find.text('Calculate Estimate'));
      await tester.pump(); // Mid-flight frame
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      completer.complete(_availableResponse);
      await tester.pumpAndSettle();
    });

    testWidgets('4. available=false shows unavailable banner', (tester) async {
      await tester.pumpWidget(_buildModal(quoteResponse: _unavailableResponse));
      await tester.enterText(find.byType(TextFormField).first, '10000');
      await tester.pump();
      await _tapButton(tester, find.text('Calculate Estimate'));
      await tester.pumpAndSettle();

      expect(find.textContaining('unavailable'), findsWidgets);
    });

    testWidgets('5. available=true shows preview card', (tester) async {
      await tester.pumpWidget(_buildModal(quoteResponse: _availableResponse));
      await tester.enterText(find.byType(TextFormField).first, '10000');
      await tester.pump();
      await _tapButton(tester, find.text('Calculate Estimate'));
      await tester.pumpAndSettle();

      expect(find.text('Estimated Loan Preview'), findsOneWidget);
    });

    testWidgets('6. Preview card shows estimated monthly rate as percentage', (tester) async {
      await tester.pumpWidget(_buildModal(quoteResponse: _availableResponse));
      await tester.enterText(find.byType(TextFormField).first, '10000');
      await tester.pump();
      await _tapButton(tester, find.text('Calculate Estimate'));
      await tester.pumpAndSettle();

      expect(find.textContaining('10%'), findsOneWidget);
    });

    testWidgets('7. Preview card shows Total Interest', (tester) async {
      await tester.pumpWidget(_buildModal(quoteResponse: _availableResponse));
      await tester.enterText(find.byType(TextFormField).first, '10000');
      await tester.pump();
      await _tapButton(tester, find.text('Calculate Estimate'));
      await tester.pumpAndSettle();

      expect(find.text('Estimated Interest'), findsOneWidget);
    });

    testWidgets('8. Preview card shows Total Repayment', (tester) async {
      await tester.pumpWidget(_buildModal(quoteResponse: _availableResponse));
      await tester.enterText(find.byType(TextFormField).first, '10000');
      await tester.pump();
      await _tapButton(tester, find.text('Calculate Estimate'));
      await tester.pumpAndSettle();

      expect(find.text('Estimated Total Repayment'), findsOneWidget);
    });

    testWidgets('9. Preview card shows disclaimer', (tester) async {
      await tester.pumpWidget(_buildModal(quoteResponse: _availableResponse));
      await tester.enterText(find.byType(TextFormField).first, '10000');
      await tester.pump();
      await _tapButton(tester, find.text('Calculate Estimate'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Estimate only'), findsOneWidget);
    });

    testWidgets('10. Changing Amount clears quote and shows stale message', (tester) async {
      await tester.pumpWidget(_buildModal(quoteResponse: _availableResponse));
      await tester.enterText(find.byType(TextFormField).first, '10000');
      await tester.pump();
      await _tapButton(tester, find.text('Calculate Estimate'));
      await tester.pumpAndSettle();
      expect(find.text('Estimated Loan Preview'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '20000');
      await tester.pump();

      expect(find.text('Estimated Loan Preview'), findsNothing);
    });

    testWidgets('11. Changing Duration clears quote', (tester) async {
      await tester.pumpWidget(_buildModal(quoteResponse: _availableResponse));
      await tester.enterText(find.byType(TextFormField).first, '10000');
      await tester.pump();
      await _tapButton(tester, find.text('Calculate Estimate'));
      await tester.pumpAndSettle();
      expect(find.text('Estimated Loan Preview'), findsOneWidget);

      await _tapButton(tester, find.text('1 Month'));
      await tester.pumpAndSettle();
      await _tapButton(tester, find.text('2 Months'));
      await tester.pumpAndSettle();

      expect(find.text('Estimated Loan Preview'), findsNothing);
    });

    testWidgets('14. Quote API error shows SnackBar, Submit still enabled', (tester) async {
      await tester.pumpWidget(_buildModal(quoteResponse: _unavailableResponse, shouldThrow: true));
      await tester.enterText(find.byType(TextFormField).first, '10000');
      await tester.pump();
      await _tapButton(tester, find.text('Calculate Estimate'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);

      final submitFinder = find.text('Submit Request');
      expect(submitFinder, findsOneWidget);
      final submitButton = tester.widget<FilledButton>(
        find.ancestor(of: submitFinder, matching: find.byType(FilledButton)),
      );
      expect(submitButton.onPressed, isNotNull);
    });

    testWidgets('15. Submit works independently of quote state', (tester) async {
      await tester.pumpWidget(_buildModal(quoteResponse: _unavailableResponse));

      await tester.enterText(find.byType(TextFormField).first, '10000');
      await tester.pump();

      final submitFinder = find.text('Submit Request');
      expect(submitFinder, findsOneWidget);
      final submitButton = tester.widget<FilledButton>(
        find.ancestor(of: submitFinder, matching: find.byType(FilledButton)),
      );
      expect(submitButton.onPressed, isNotNull);
    });
  });
}
