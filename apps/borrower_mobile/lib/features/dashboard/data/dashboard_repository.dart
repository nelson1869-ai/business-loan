import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/features/dashboard/data/dashboard_local_cache.dart';
import 'package:borrower_mobile/features/dashboard/models/borrower_dashboard.dart';

class DashboardRepository {
  final ApiClient apiClient;
  final DashboardLocalCache localCache;

  DashboardRepository({
    required this.apiClient,
    DashboardLocalCache? localCache,
  }) : localCache = localCache ?? DashboardLocalCache();

  Future<BorrowerDashboard> getDashboard() async {
    try {
      final json = await apiClient.get('/api/v1/client/dashboard');
      final dashboard = BorrowerDashboard.fromJson(json, isFromCache: false);
      await localCache.saveCachedDashboard(dashboard);
      return dashboard;
    } catch (e) {
      final cached = await localCache.getCachedDashboard();
      if (cached != null) {
        return cached.copyWith(isFromCache: true);
      }
      rethrow;
    }
  }
}
