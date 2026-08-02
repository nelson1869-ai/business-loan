import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:borrower_mobile/features/loans/data/loan_repository.dart';
import 'package:borrower_mobile/features/loans/models/borrower_loan.dart';

class LoansListState {
  final bool isLoading;
  final List<BorrowerLoanListItem> items;
  final int total;
  final int offset;
  final int limit;
  final String selectedStatus;
  final String? errorMessage;
  final bool isFromCache;
  final DateTime? lastUpdated;

  const LoansListState({
    this.isLoading = false,
    this.items = const [],
    this.total = 0,
    this.offset = 0,
    this.limit = 20,
    this.selectedStatus = 'all',
    this.errorMessage,
    this.isFromCache = false,
    this.lastUpdated,
  });

  LoansListState copyWith({
    bool? isLoading,
    List<BorrowerLoanListItem>? items,
    int? total,
    int? offset,
    int? limit,
    String? selectedStatus,
    String? errorMessage,
    bool? isFromCache,
    DateTime? lastUpdated,
    bool clearError = false,
  }) {
    return LoansListState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      total: total ?? this.total,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isFromCache: isFromCache ?? this.isFromCache,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class LoansListNotifier extends StateNotifier<LoansListState> {
  final LoanRepository repository;
  final String borrowerAccountId;

  LoansListNotifier({
    required this.repository,
    required this.borrowerAccountId,
  }) : super(const LoansListState()) {
    loadLoans();
  }

  Future<void> loadLoans({
    String? status,
    bool isRefresh = false,
  }) async {
    final statusFilter = status ?? state.selectedStatus;

    if (!isRefresh && state.items.isEmpty) {
      state = state.copyWith(
        isLoading: true,
        selectedStatus: statusFilter,
        clearError: true,
      );
    } else {
      state = state.copyWith(selectedStatus: statusFilter, clearError: true);
    }

    try {
      final response = await repository.getLoans(
        borrowerAccountId: borrowerAccountId,
        status: statusFilter,
        offset: 0,
        limit: 20,
      );

      final isCached = response.items.isNotEmpty &&
          response.items.first.updatedAt.isBefore(
            DateTime.now().subtract(const Duration(minutes: 1)),
          );

      state = state.copyWith(
        isLoading: false,
        items: response.items,
        total: response.total,
        offset: response.offset,
        limit: response.limit,
        isFromCache: isCached,
        lastUpdated: response.items.isNotEmpty ? response.items.first.updatedAt : DateTime.now(),
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> setStatusFilter(String status) async {
    if (state.selectedStatus == status) return;
    await loadLoans(status: status, isRefresh: true);
  }
}

class LoanDetailState {
  final bool isLoading;
  final BorrowerLoanDetail? detail;
  final String? errorMessage;

  const LoanDetailState({
    this.isLoading = false,
    this.detail,
    this.errorMessage,
  });

  LoanDetailState copyWith({
    bool? isLoading,
    BorrowerLoanDetail? detail,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LoanDetailState(
      isLoading: isLoading ?? this.isLoading,
      detail: detail ?? this.detail,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LoanDetailNotifier extends StateNotifier<LoanDetailState> {
  final LoanRepository repository;
  final String borrowerAccountId;
  final String loanId;

  LoanDetailNotifier({
    required this.repository,
    required this.borrowerAccountId,
    required this.loanId,
  }) : super(const LoanDetailState()) {
    loadDetail();
  }

  Future<void> loadDetail() async {
    if (state.detail == null) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final detail = await repository.getLoanDetail(
        borrowerAccountId: borrowerAccountId,
        loanId: loanId,
      );
      state = state.copyWith(
        isLoading: false,
        detail: detail,
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

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LoanRepository(apiClient: apiClient);
});

final loansListNotifierProvider =
    StateNotifierProvider<LoansListNotifier, LoansListState>((ref) {
  final repository = ref.watch(loanRepositoryProvider);
  final authState = ref.watch(authNotifierProvider);
  final accountId = authState.borrowerAccountId ?? '';

  return LoansListNotifier(
    repository: repository,
    borrowerAccountId: accountId,
  );
});

final loanDetailNotifierProvider = StateNotifierProvider.family
    .autoDispose<LoanDetailNotifier, LoanDetailState, String>((ref, loanId) {
  final repository = ref.watch(loanRepositoryProvider);
  final authState = ref.watch(authNotifierProvider);
  final accountId = authState.borrowerAccountId ?? '';

  return LoanDetailNotifier(
    repository: repository,
    borrowerAccountId: accountId,
    loanId: loanId,
  );
});
