import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/business_setting.dart';

class BusinessSettingRepository {
  const BusinessSettingRepository(this._dio, this._storage);

  final Dio _dio;
  final FlutterSecureStorage _storage;
  static const _cacheKey = 'cache.business_settings';

  Future<BusinessSetting> load() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.businessSettings,
      );
      final settings = BusinessSetting.fromJson(response.data!);
      await _storage.write(
        key: _cacheKey,
        value: jsonEncode(settings.toJson()),
      );
      return settings;
    } on DioException catch (error) {
      if (error.response != null) rethrow;
      final cached = await _storage.read(key: _cacheKey);
      if (cached == null) rethrow;
      return BusinessSetting.fromJson(
        Map<String, dynamic>.from(jsonDecode(cached) as Map),
      );
    }
  }

  Future<BusinessSetting> save({
    required String businessName,
    required String currencyCode,
    required String receiptFooter,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.businessSettings,
      data: {
        'businessName': businessName,
        'currencyCode': currencyCode,
        'receiptFooter': receiptFooter,
      },
    );
    final settings = BusinessSetting.fromJson(response.data!);
    await _storage.write(key: _cacheKey, value: jsonEncode(settings.toJson()));
    return settings;
  }
}

final businessSettingRepositoryProvider = Provider<BusinessSettingRepository>((
  ref,
) {
  return BusinessSettingRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  );
});
