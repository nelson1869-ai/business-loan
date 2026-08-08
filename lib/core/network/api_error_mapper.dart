import 'package:dio/dio.dart';

/// Converts transport and HTTP failures into safe user-facing messages.
class ApiErrorMapper {
  ApiErrorMapper._();

  static String message(Object error) {
    if (error is! DioException) {
      final str = error.toString().replaceAll('Exception: ', '').trim();
      return str.isNotEmpty && !str.startsWith('Instance of ')
          ? str
          : 'Something went wrong. Please try again.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'No server connection. This action requires an online connection.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'The server took too long to respond. Please try again.';
    }
    return switch (error.response?.statusCode) {
      400 => _safeDetail(error) ?? 'The request could not be processed.',
      401 => 'Your session has expired. Please sign in again.',
      403 => _safeDetail(error) ?? 'You do not have permission to perform this action.',
      404 =>
        _safeDetail(error) ??
            'I could not find a matching record. Try a name or another request.',
      409 => _safeDetail(error) ?? 'The record changed or already exists.',
      413 => 'The selected file is too large.',
      422 => _safeDetail(error) ?? 'Check the entered values and try again.',
      429 => 'Too many requests. Wait a moment and try again.',
      final code when code != null && code >= 500 =>
        _safeDetail(error) ?? 'The server could not complete the request. Please try again.',
      _ => _safeDetail(error) ?? 'Something went wrong. Please try again.',
    };
  }

  /// Returns true only for transport failures safe to defer to the offline
  /// queue. HTTP validation and authorization failures must never be queued.
  static bool isOfflineFailure(Object error) {
    return error is DioException &&
        error.response == null &&
        {
          DioExceptionType.connectionError,
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.sendTimeout,
        }.contains(error.type);
  }

  static String? _safeDetail(DioException error) {
    final data = error.response?.data;
    if (data is String && data.trim().isNotEmpty && data.length <= 300) {
      return data.trim();
    }
    if (data is! Map) return null;
    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty && detail.length <= 300) {
      return detail.trim();
    }
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] is String) {
        return first['msg'] as String;
      }
    }
    return null;
  }
}
