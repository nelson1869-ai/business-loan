import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:borrower_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:borrower_mobile/features/dashboard/models/borrower_dashboard.dart';

class DashboardState {
  final bool isLoading;
  final BorrowerDashboard? dashboard;
  final String? errorMessage;

  const DashboardState({
    this.isLoading = false,
    this.dashboard,
    this.errorMessage,
  });

  DashboardState copyWith({
    bool? isLoading,
    BorrowerDashboard? dashboard,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      dashboard: dashboard ?? this.dashboard,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final DashboardRepository repository;

  DashboardNotifier(this.repository) : super(const DashboardState()) {
    loadDashboard();
  }

  Future<void> loadDashboard({bool isRefresh = false}) async {
    if (!isRefresh && state.dashboard == null) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final dashboard = await repository.getDashboard();
      state = state.copyWith(
        isLoading: false,
        dashboard: dashboard,
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

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DashboardRepository(apiClient: apiClient);
});

final dashboardNotifierProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final repository = ref.watch(dashboardRepositoryProvider);
  return DashboardNotifier(repository);
});
