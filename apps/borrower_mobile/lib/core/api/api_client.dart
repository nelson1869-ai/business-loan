import 'package:dio/dio.dart';
import 'package:borrower_mobile/core/api/api_error.dart';
import 'package:borrower_mobile/core/api/auth_interceptor.dart';
import 'package:borrower_mobile/core/config/env_config.dart';
import 'package:borrower_mobile/core/storage/secure_token_storage.dart';

/// Central API client for borrower portal.
class ApiClient {
  late final Dio _dio;
  final SecureTokenStorage tokenStorage;
  final void Function()? onUnrecoverableAuthError;

  ApiClient({
    required this.tokenStorage,
    this.onUnrecoverableAuthError,
    String? baseUrl,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? EnvConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      AuthInterceptor(
        tokenStorage: tokenStorage,
        dio: _dio,
        onUnrecoverableAuthError: onUnrecoverableAuthError,
      ),
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await _dio.get(path);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      await _dio.delete(path);
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}
