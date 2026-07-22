import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_repository.dart';
import '../domain/dashboard_data.dart';

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this._repository) : super(const DashboardState());

  final DashboardRepository _repository;

  Future<void> loadDashboard() async {
    state = const DashboardState(isLoading: true);
    state = await _repository.loadDashboard();
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
      return DashboardNotifier(ref.watch(dashboardRepositoryProvider));
    });
