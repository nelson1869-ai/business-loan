import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:borrower_mobile/features/dashboard/models/borrower_dashboard.dart';

class DashboardLocalCache {
  final FlutterSecureStorage _storage;

  DashboardLocalCache({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  String _cacheKey([String? borrowerAccountId]) =>
      (borrowerAccountId != null && borrowerAccountId.isNotEmpty)
          ? 'cached_borrower_dashboard_$borrowerAccountId'
          : 'cached_borrower_dashboard';

  Future<BorrowerDashboard?> getCachedDashboard([String? borrowerAccountId]) async {
    try {
      final key = _cacheKey(borrowerAccountId);
      final rawJson = await _storage.read(key: key);
      if (rawJson != null && rawJson.isNotEmpty) {
        final map = jsonDecode(rawJson) as Map<String, dynamic>;
        return BorrowerDashboard.fromJson(map, isFromCache: true);
      }
      if (borrowerAccountId != null && borrowerAccountId.isNotEmpty) {
        final fallbackJson =
            await _storage.read(key: 'cached_borrower_dashboard');
        if (fallbackJson != null && fallbackJson.isNotEmpty) {
          final map = jsonDecode(fallbackJson) as Map<String, dynamic>;
          return BorrowerDashboard.fromJson(map, isFromCache: true);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedDashboard(
      BorrowerDashboard dashboard, [String? borrowerAccountId]) async {
    try {
      final key = _cacheKey(borrowerAccountId ?? dashboard.borrower.id);
      final rawJson = jsonEncode(dashboard.toJson());
      await _storage.write(key: key, value: rawJson);
      await _storage.write(key: 'cached_borrower_dashboard', value: rawJson);
    } catch (_) {}
  }

  Future<void> clearAllCachedDashboards() async {
    try {
      final allKeys = await _storage.readAll();
      for (final key in allKeys.keys) {
        if (key.startsWith('cached_borrower_dashboard')) {
          await _storage.delete(key: key);
        }
      }
    } catch (_) {}
  }
}
