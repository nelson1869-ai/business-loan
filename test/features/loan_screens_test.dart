import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/loans/data/models/loan_create_request.dart';
import 'package:lending_nelson/features/loans/data/repositories/remote_loan_repository.dart';
import 'package:lending_nelson/features/loans/domain/models/installment.dart';
import 'package:lending_nelson/features/loans/domain/models/loan.dart';
import 'package:lending_nelson/core/utils/formatters.dart';
import 'package:lending_nelson/features/loans/presentation/loan_create_screen.dart';
import 'package:lending_nelson/features/loans/presentation/loan_detail_screen.dart';
import 'package:lending_nelson/features/loans/presentation/providers/loans_provider.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lending_nelson/core/network/server_health_service.dart';

class FakeConnectivity implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.wifi,
  ];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

class FakeServerHealthService extends ServerHealthService {
  FakeServerHealthService([this.reachable = true]) : super(FakeConnectivity());
  final bool reachable;

  @override
  Future<bool> isServerReachable() async => reachable;
}

void main() {
  test('percentage conversion stays exact without binary floating point', () {
    expect(percentageToDecimalRate('10'), '0.1');
    expect(percentageToDecimalRate('10.5'), '0.105');
    expect(percentageToDecimalRate('0.125'), '0.00125');
  });

  testWidgets('create form validates required financial terms', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverHealthServiceProvider.overrideWithValue(
            FakeServerHealthService(true),
          ),
          borrowerLoansProvider(
            'borrower-1',
          ).overrideWith((ref) => Future.value(const [])),
        ],
        child: const MaterialApp(
          home: LoanCreateScreen(borrowerId: 'borrower-1'),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Create Loan'));
    await tester.pump();

    expect(
      find.text('Enter a positive amount with up to 2 decimal places'),
      findsOneWidget,
    );
  });

  testWidgets(
    'loan creation never calls the remote repository in the foreground',
    (tester) async {
      final repository = _FailingLoanRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverHealthServiceProvider.overrideWithValue(
              FakeServerHealthService(true),
            ),
            remoteLoanRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: LoanCreateScreen(borrowerId: 'borrower-1'),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, '1000.00');

      final btn = find.widgetWithText(FilledButton, 'Create Loan');
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(repository.requests, isEmpty);
    },
  );

  testWidgets('submit does not wait for a pending remote request', (
    tester,
  ) async {
    final repository = _PendingLoanRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverHealthServiceProvider.overrideWithValue(
            FakeServerHealthService(true),
          ),
          remoteLoanRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: LoanCreateScreen(borrowerId: 'borrower-1'),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, '1000.00');

    await tester.tap(find.widgetWithText(FilledButton, 'Create Loan'));
    await tester.pump();
    expect(repository.requests, isEmpty);
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
    expect(find.text('Payment 1 · \$129.50'), findsOneWidget);
    expect(find.text('8/5/2026 · Scheduled'), findsOneWidget);

    await tester.ensureVisible(find.text('Payment 1 · \$129.50'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payment 1 · \$129.50'));
    await tester.pumpAndSettle();
    expect(find.text('Interest'), findsOneWidget);
    expect(find.text('\$50.00'), findsOneWidget);
    expect(find.text('Remaining principal'), findsOneWidget);
    expect(find.text('\$920.50'), findsOneWidget);
  });
}

class _FailingLoanRepository extends RemoteLoanRepository {
  _FailingLoanRepository() : super(Dio());

  final List<LoanCreateRequest> requests = <LoanCreateRequest>[];

  @override
  Future<Loan> createLoan(LoanCreateRequest request) async {
    requests.add(request);
    throw const RemoteLoanException('Temporary failure', isRetryable: true);
  }
}

class _PendingLoanRepository extends RemoteLoanRepository {
  _PendingLoanRepository() : super(Dio());

  final List<LoanCreateRequest> requests = <LoanCreateRequest>[];
  final Completer<Loan> completer = Completer<Loan>();

  @override
  Future<Loan> createLoan(LoanCreateRequest request) {
    requests.add(request);
    return completer.future;
  }
}

Loan _loan() => Loan(
  id: 'loan-1',
  requestId: '00000000-0000-4000-8000-000000000002',
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
