import 'package:dio/dio.dart';

/// Structured API error model for borrower portal client.
class ApiError implements Exception {
  final String message;
  final int? statusCode;

  const ApiError({required this.message, this.statusCode});

  factory ApiError.fromDioException(DioException error) {
    if (error.response != null && error.response?.data is Map) {
      final data = error.response?.data as Map;
      final detail = data['detail'] ?? data['message'];
      if (detail is String) {
        return ApiError(
          message: detail,
          statusCode: error.response?.statusCode,
        );
      }
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const ApiError(message: 'Connection timed out. Please try again.');
    }
    if (error.type == DioExceptionType.connectionError) {
      return const ApiError(
          message: 'Network error. Please check your connection.');
    }

    return ApiError(
      message: error.message ?? 'An unexpected error occurred.',
      statusCode: error.response?.statusCode,
    );
  }

  @override
  String toString() => 'ApiError(statusCode: $statusCode, message: $message)';
}
