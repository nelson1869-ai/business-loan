import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:borrower_mobile/features/payments/data/payment_repository.dart';
import 'package:borrower_mobile/features/payments/models/borrower_payment.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaymentRepository(apiClient: apiClient);
});

class LoanPaymentsState {
  final bool isLoading;
  final BorrowerPaymentHistory? history;
  final String? errorMessage;

  const LoanPaymentsState({
    this.isLoading = false,
    this.history,
    this.errorMessage,
  });

  LoanPaymentsState copyWith({
    bool? isLoading,
    BorrowerPaymentHistory? history,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LoanPaymentsState(
      isLoading: isLoading ?? this.isLoading,
      history: history ?? this.history,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LoanPaymentsNotifier extends StateNotifier<LoanPaymentsState> {
  final PaymentRepository repository;
  final String borrowerAccountId;
  final String loanId;

  LoanPaymentsNotifier({
    required this.repository,
    required this.borrowerAccountId,
    required this.loanId,
  }) : super(const LoanPaymentsState()) {
    if (borrowerAccountId.isNotEmpty && loanId.isNotEmpty) {
      loadPayments();
    }
  }

  Future<void> loadPayments() async {
    if (state.history == null) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final history = await repository.getLoanPayments(
        borrowerAccountId: borrowerAccountId,
        loanId: loanId,
      );
      state = state.copyWith(
        isLoading: false,
        history: history,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

final loanPaymentsNotifierProvider = StateNotifierProvider.family
    .autoDispose<LoanPaymentsNotifier, LoanPaymentsState, String>(
        (ref, loanId) {
  final repository = ref.watch(paymentRepositoryProvider);
  final accountId = ref.watch(
    authNotifierProvider.select((auth) => auth.borrowerAccountId),
  );

  return LoanPaymentsNotifier(
    repository: repository,
    borrowerAccountId: accountId ?? '',
    loanId: loanId,
  );
});

class PaymentReceiptState {
  final bool isLoading;
  final BorrowerReceiptDetail? receipt;
  final String? errorMessage;

  const PaymentReceiptState({
    this.isLoading = false,
    this.receipt,
    this.errorMessage,
  });

  PaymentReceiptState copyWith({
    bool? isLoading,
    BorrowerReceiptDetail? receipt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PaymentReceiptState(
      isLoading: isLoading ?? this.isLoading,
      receipt: receipt ?? this.receipt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PaymentReceiptNotifier extends StateNotifier<PaymentReceiptState> {
  final PaymentRepository repository;
  final String borrowerAccountId;
  final String paymentId;

  PaymentReceiptNotifier({
    required this.repository,
    required this.borrowerAccountId,
    required this.paymentId,
  }) : super(const PaymentReceiptState()) {
    if (borrowerAccountId.isNotEmpty && paymentId.isNotEmpty) {
      loadReceipt();
    }
  }

  Future<void> loadReceipt() async {
    if (state.receipt == null) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final receipt = await repository.getPaymentReceipt(
        borrowerAccountId: borrowerAccountId,
        paymentId: paymentId,
      );
      state = state.copyWith(
        isLoading: false,
        receipt: receipt,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

final paymentReceiptNotifierProvider = StateNotifierProvider.family
    .autoDispose<PaymentReceiptNotifier, PaymentReceiptState, String>(
        (ref, paymentId) {
  final repository = ref.watch(paymentRepositoryProvider);
  final accountId = ref.watch(
    authNotifierProvider.select((auth) => auth.borrowerAccountId),
  );

  return PaymentReceiptNotifier(
    repository: repository,
    borrowerAccountId: accountId ?? '',
    paymentId: paymentId,
  );
});
