import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/business_setting.dart';

class BusinessSettingRepository {
  const BusinessSettingRepository(this._dio);

  final Dio _dio;

  Future<BusinessSetting> load() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.businessSettings,
    );
    return BusinessSetting.fromJson(response.data!);
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
    return BusinessSetting.fromJson(response.data!);
  }
}

final businessSettingRepositoryProvider = Provider<BusinessSettingRepository>((
  ref,
) {
  return BusinessSettingRepository(ref.watch(apiClientProvider));
});
