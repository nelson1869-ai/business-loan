import 'package:dio/dio.dart';

import '../network/api_endpoints.dart';

/// Transport boundary for submitting an already ordered sync batch.
abstract interface class SyncBatchClient {
  Future<Object?> submit(List<Map<String, dynamic>> items);
}

/// Dio implementation of the sync transport contract.
class DioSyncBatchClient implements SyncBatchClient {
  const DioSyncBatchClient(this._dio);

  final Dio _dio;

  @override
  Future<Object?> submit(List<Map<String, dynamic>> items) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.syncDrain,
      data: {'items': items},
    );
    return response.data;
  }
}
