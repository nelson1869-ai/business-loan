import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/offline_sync_service.dart';
import '../domain/business_setting.dart';

class BusinessSettingRepository {
  const BusinessSettingRepository(this._dio, this._storage, this._sync);

  final Dio _dio;
  final FlutterSecureStorage _storage;
  final OfflineSyncService _sync;
  static const _cacheKey = 'cache.business_settings';

  Future<BusinessSetting> load() async {
    final cached = await _storage.read(key: _cacheKey);
    if (cached != null) {
      unawaited(_refresh());
      return BusinessSetting.fromJson(
        Map<String, dynamic>.from(jsonDecode(cached) as Map),
      );
    }
    unawaited(_refresh());
    return BusinessSetting(
      businessName: 'Lending Nelson',
      currencyCode: 'PHP',
      receiptFooter: '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      // defaultMonthlyEstimateRate remains null until a server fetch succeeds
    );
  }

  Future<void> _refresh() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.businessSettings,
      );
      final settings = BusinessSetting.fromJson(response.data!);
      await _storage.write(
        key: _cacheKey,
        value: jsonEncode(settings.toJson()),
      );
    } catch (_) {}
  }

  Future<BusinessSetting> save({
    required String businessName,
    required String currencyCode,
    required String receiptFooter,
    String? defaultMonthlyEstimateRate,
  }) async {
    final payload = <String, dynamic>{
      'businessName': businessName,
      'currencyCode': currencyCode,
      'receiptFooter': receiptFooter,
      'defaultMonthlyEstimateRate': defaultMonthlyEstimateRate,
    };
    final settings = BusinessSetting(
      businessName: businessName,
      currencyCode: currencyCode,
      receiptFooter: receiptFooter,
      updatedAt: DateTime.now(),
      defaultMonthlyEstimateRate: defaultMonthlyEstimateRate,
    );
    await _storage.write(key: _cacheKey, value: jsonEncode(settings.toJson()));
    await _sync.enqueue(
      endpoint: ApiEndpoints.businessSettings,
      method: 'PUT',
      payload: payload,
      entityType: 'business_setting',
      entityLocalId: 'default',
      operationType: 'update',
    );
    unawaited(_sync.drainQueue());
    return settings;
  }
}

final businessSettingRepositoryProvider = Provider<BusinessSettingRepository>((
  ref,
) {
  return BusinessSettingRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
    ref.watch(offlineSyncServiceProvider),
  );
});
