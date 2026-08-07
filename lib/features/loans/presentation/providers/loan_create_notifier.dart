import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../data/models/loan_create_request.dart';
import '../../data/models/loan_quote.dart';
import '../../data/repositories/remote_loan_repository.dart';
import '../../domain/models/loan.dart';
import '../../../borrowers/data/borrower_repository.dart';
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
  LoanCreateNotifier(this._remoteLoanRepository, this.ref)
    : super(const LoanCreateState());

  final RemoteLoanRepository _remoteLoanRepository;
  final Ref ref;
  String? _requestId;
  String? _requestFingerprint;

  Future<LoanQuote?> calculateQuote({
    required String principal,
    required String rate,
    required int termMonths,
    required int paymentsPerMonth,
    required DateTime firstDueDate,
    String repaymentStructure = 'principal_plus_interest',
  }) async {
    state = const LoanCreateState(isCalculating: true);
    final monthlyRateStr = percentageToDecimalRate(rate);
    try {
      final quote = await _remoteLoanRepository.calculateQuote(
        principal: principal,
        monthlyRate: monthlyRateStr,
        termMonths: termMonths,
        paymentsPerMonth: paymentsPerMonth,
        firstDueDate: formatDateOnly(firstDueDate),
        repaymentStructure: repaymentStructure,
      );
      state = LoanCreateState(quote: quote);
      return quote;
    } catch (error) {
      state = LoanCreateState(error: ApiErrorMapper.message(error));
      return null;
    }
  }

  Future<Loan?> submit({
    required String borrowerId,
    required String principal,
    required String rate,
    required int termMonths,
    required int paymentsPerMonth,
    required DateTime startDate,
    required DateTime firstDueDate,
    String repaymentStructure = 'principal_plus_interest',
  }) async {
    if (!firstDueDate.isAfter(startDate)) {
      state = const LoanCreateState(
        error: 'First due date must be after start date',
      );
      return null;
    }

    state = const LoanCreateState(isSubmitting: true);
    final borrowerVerified = await ref.read(
      borrowerServerVerifiedProvider(borrowerId).future,
    );
    if (!borrowerVerified) {
      state = const LoanCreateState(
        error:
            'Borrower identity verification is pending. Sync the borrower before creating a loan.',
      );
      return null;
    }
    final fingerprint = <Object>[
      borrowerId,
      principal,
      rate,
      termMonths,
      paymentsPerMonth,
      formatDateOnly(startDate),
      formatDateOnly(firstDueDate),
      repaymentStructure,
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
      repaymentStructure: repaymentStructure,
    );

    try {
      final loan = await _remoteLoanRepository.createDraft(createRequest);
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
      state = LoanCreateState(error: ApiErrorMapper.message(error));
      return null;
    }
  }
}

final loanCreateNotifierProvider =
    StateNotifierProvider.autoDispose<LoanCreateNotifier, LoanCreateState>((
      ref,
    ) {
      return LoanCreateNotifier(ref.watch(remoteLoanRepositoryProvider), ref);
    });
