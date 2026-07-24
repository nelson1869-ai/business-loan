import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/formatters.dart';
import '../../data/models/loan_create_request.dart';
import '../../data/models/loan_quote.dart';
import '../../data/repositories/remote_loan_repository.dart';
import '../../domain/models/loan.dart';
import '../../../borrowers/data/remote_borrower_repository.dart';
import '../../../borrowers/domain/borrower_model.dart';
import '../../../../core/network/server_health_service.dart';
import 'loans_provider.dart';

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
  LoanCreateNotifier(
    this._loanRepository,
    this._remoteBorrowerRepository,
    this.ref,
  ) : super(const LoanCreateState());

  final RemoteLoanRepository _loanRepository;
  final RemoteBorrowerRepository _remoteBorrowerRepository;
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
    try {
      final quote = await _loanRepository.calculateQuote(
        principal: principal,
        monthlyRate: percentageToDecimalRate(rate),
        termMonths: termMonths,
        paymentsPerMonth: paymentsPerMonth,
        firstDueDate: formatDateOnly(firstDueDate),
      );
      state = LoanCreateState(quote: quote);
      return quote;
    } on RemoteLoanException catch (error) {
      state = LoanCreateState(error: error.message);
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
      state = LoanCreateState(error: 'First due date must be after start date');
      return null;
    }

    state = LoanCreateState(isSubmitting: true);
    try {
      final isOnline = await ref
          .read(serverHealthServiceProvider)
          .isServerReachable();
      if (borrower != null && isOnline) {
        try {
          await _remoteBorrowerRepository.ensureBorrowerExists(borrower);
        } catch (_) {}
      }
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

      final loan = await _loanRepository.createLoan(
        LoanCreateRequest(
          borrowerId: borrowerId,
          requestId: _requestId!,
          originalPrincipal: principal,
          monthlyRate: percentageToDecimalRate(rate),
          termMonths: termMonths,
          paymentsPerMonth: paymentsPerMonth,
          startDate: formatDateOnly(startDate),
          firstDueDate: formatDateOnly(firstDueDate),
        ),
      );
      ref.invalidate(borrowerLoansProvider(borrowerId));
      state = LoanCreateState(createdLoan: loan);
      return loan;
    } on RemoteLoanException catch (error) {
      state = LoanCreateState(error: error.message);
      return null;
    } on RemoteBorrowerException catch (error) {
      state = LoanCreateState(error: error.message);
      return null;
    }
  }
}

final loanCreateNotifierProvider =
    StateNotifierProvider.autoDispose<LoanCreateNotifier, LoanCreateState>((
      ref,
    ) {
      return LoanCreateNotifier(
        ref.watch(remoteLoanRepositoryProvider),
        ref.watch(remoteBorrowerRepositoryProvider),
        ref,
      );
    });
