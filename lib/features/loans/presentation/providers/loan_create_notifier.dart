import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/loan_calculator.dart';
import '../../data/models/loan_create_request.dart';
import '../../data/models/loan_quote.dart';
import '../../data/repositories/local_loan_repository.dart';
import '../../domain/models/loan.dart';
import '../../../borrowers/data/borrower_repository.dart';
import '../../../borrowers/domain/borrower_model.dart';
import '../../../../core/network/offline_sync_service.dart';
import '../../../../core/network/api_endpoints.dart';
import 'loans_provider.dart';
import '../../../borrower_communication/data/borrower_due_reminder_scheduler.dart';

class LoanCreateState {
  final bool isSubmitting;
  final String? error;
  final Loan? createdLoan;
  final LoanQuote? quote;
  final bool isCalculating;

  const LoanCreateState({
    this.isSubmitting = false,
    this.error,
    this.createdLoan,
    this.quote,
    this.isCalculating = false,
  });
}

class LoanCreateNotifier extends StateNotifier<LoanCreateState> {
  LoanCreateNotifier(this._localLoanRepository, this.ref)
    : super(const LoanCreateState());

  final LocalLoanRepository _localLoanRepository;
  final Ref ref;
  String? _requestId;
  String? _requestFingerprint;

  Future<LoanQuote?> calculateQuote({
    required String principal,
    required String rate,
    required int termMonths,
    required int paymentsPerMonth,
    required DateTime firstDueDate,
  }) async {
    state = const LoanCreateState(isCalculating: true);
    final monthlyRateStr = percentageToDecimalRate(rate);
    final double periodicRate =
        (double.tryParse(monthlyRateStr) ?? 0.0) / paymentsPerMonth;

    try {
      final schedule = LoanCalculator.buildInstallmentSchedule(
        originalPrincipal: principal,
        periodicRate: periodicRate,
        numberOfPayments: termMonths * paymentsPerMonth,
      );
      int totalIntCents = 0;
      for (final item in schedule) {
        totalIntCents += LoanCalculator.parseCents(
          item.interestAmount,
          'interest',
        );
      }
      final totalRepaymentCents =
          LoanCalculator.parseCents(principal, 'principal') + totalIntCents;

      final firstDueStr = formatDateOnly(firstDueDate);
      final firstDueDT = DateTime.parse(firstDueStr);
      final finalDueDT = DateTime(
        firstDueDT.year,
        firstDueDT.month + schedule.length - 1,
        firstDueDT.day,
      );
      final finalDueDateStr = formatDateOnly(finalDueDT);

      final quote = LoanQuote(
        regularPaymentAmount: schedule.first.paymentAmount,
        totalInterest: LoanCalculator.formatCents(totalIntCents),
        totalRepayment: LoanCalculator.formatCents(totalRepaymentCents),
        numberOfPayments: schedule.length,
        finalDueDate: finalDueDateStr,
      );
      state = LoanCreateState(quote: quote);
      return quote;
    } catch (error) {
      state = LoanCreateState(error: error.toString());
      return null;
    }
  }

  Future<Loan?> submit({
    required String borrowerId,
    required Borrower? borrower,
    required String principal,
    required String rate,
    required int termMonths,
    required int paymentsPerMonth,
    required DateTime startDate,
    required DateTime firstDueDate,
  }) async {
    if (!firstDueDate.isAfter(startDate)) {
      state = const LoanCreateState(
        error: 'First due date must be after start date',
      );
      return null;
    }

    state = const LoanCreateState(isSubmitting: true);
    final fingerprint = <Object>[
      borrowerId,
      principal,
      rate,
      termMonths,
      paymentsPerMonth,
      formatDateOnly(startDate),
      formatDateOnly(firstDueDate),
    ].join('|');
    if (_requestFingerprint != fingerprint) {
      _requestFingerprint = fingerprint;
      _requestId = const Uuid().v4();
    }

    final createRequest = LoanCreateRequest(
      borrowerId: borrowerId,
      requestId: _requestId!,
      originalPrincipal: principal,
      monthlyRate: percentageToDecimalRate(rate),
      termMonths: termMonths,
      paymentsPerMonth: paymentsPerMonth,
      startDate: formatDateOnly(startDate),
      firstDueDate: formatDateOnly(firstDueDate),
    );

    if (borrower != null) {
      try {
        await ref.read(borrowerRepositoryProvider).saveBorrower(borrower);
      } catch (_) {}
    }

    try {
      final loan = await _localLoanRepository.createLoanOffline(createRequest);
      final syncService = ref.read(offlineSyncServiceProvider);
      await syncService.enqueue(
        endpoint: ApiEndpoints.loans,
        method: 'POST',
        payload: createRequest.toJson(),
        entityType: 'loan',
        entityLocalId: loan.id,
        operationType: 'create',
        dependencyIds: [borrowerId],
      );
      unawaited(syncService.drainQueue());
      ref.invalidate(borrowerLoansProvider(borrowerId));
      unawaited(
        ref
            .read(borrowerDueReminderSchedulerProvider)
            .refresh()
            .catchError((_) {}),
      );
      state = LoanCreateState(createdLoan: loan);
      return loan;
    } catch (error) {
      state = LoanCreateState(error: error.toString());
      return null;
    }
  }
}

final loanCreateNotifierProvider =
    StateNotifierProvider.autoDispose<LoanCreateNotifier, LoanCreateState>((
      ref,
    ) {
      return LoanCreateNotifier(ref.watch(localLoanRepositoryProvider), ref);
    });
