import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:borrower_mobile/features/dashboard/models/borrower_dashboard.dart';

class DashboardLocalCache {
  static const _cacheKey = 'cached_borrower_dashboard';
  final FlutterSecureStorage _storage;

  DashboardLocalCache({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<BorrowerDashboard?> getCachedDashboard() async {
    try {
      final rawJson = await _storage.read(key: _cacheKey);
      if (rawJson == null || rawJson.isEmpty) {
        return null;
      }
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return BorrowerDashboard.fromJson(map, isFromCache: true);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedDashboard(BorrowerDashboard dashboard) async {
    try {
      final rawJson = jsonEncode(dashboard.toJson());
      await _storage.write(key: _cacheKey, value: rawJson);
    } catch (_) {}
  }

  Future<void> clearCachedDashboard() async {
    try {
      await _storage.delete(key: _cacheKey);
    } catch (_) {}
  }
}
