import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:borrower_mobile/features/dashboard/models/borrower_dashboard.dart';

class DashboardLocalCache {
  static const _legacyCacheKey = 'cached_borrower_dashboard';
  final FlutterSecureStorage _storage;

  DashboardLocalCache({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  String _cacheKey(String borrowerAccountId) {
    final accountId = borrowerAccountId.trim();
    if (accountId.isEmpty) {
      throw ArgumentError.value(
        borrowerAccountId,
        'borrowerAccountId',
        'must not be empty',
      );
    }
    return 'cached_borrower_dashboard_$accountId';
  }

  Future<void> _deleteLegacyCache() async {
    await _storage.delete(key: _legacyCacheKey);
  }

  Future<BorrowerDashboard?> getCachedDashboard({
    required String borrowerAccountId,
  }) async {
    final key = _cacheKey(borrowerAccountId);
    try {
      await _deleteLegacyCache();
      final rawJson = await _storage.read(key: key);
      if (rawJson == null || rawJson.isEmpty) {
        return null;
      }
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return BorrowerDashboard.fromJson(map, isFromCache: true);
    } catch (_) {
      await _storage.delete(key: key).catchError((_) {});
      return null;
    }
  }

  Future<void> saveCachedDashboard({
    required String borrowerAccountId,
    required BorrowerDashboard dashboard,
  }) async {
    final key = _cacheKey(borrowerAccountId);
    await _deleteLegacyCache();
    final rawJson = jsonEncode(dashboard.toJson());
    await _storage.write(key: key, value: rawJson);
  }

  Future<void> clearCachedDashboard({
    required String borrowerAccountId,
  }) async {
    final key = _cacheKey(borrowerAccountId);
    await _deleteLegacyCache();
    await _storage.delete(key: key);
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
