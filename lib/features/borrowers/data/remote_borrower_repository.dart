import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

import '../domain/borrower_model.dart';

class RemoteBorrowerException implements Exception {
  const RemoteBorrowerException(
    this.message, {
    this.statusCode,
    required this.isRetryable,
  });

  final String message;
  final int? statusCode;
  final bool isRetryable;

  @override
  String toString() => message;
}

class RemoteBorrowerRepository {
  RemoteBorrowerRepository(this._dio);

  final Dio _dio;

  Future<void> ensureBorrowerExists(Borrower borrower) async {
    try {
      await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.borrowers}/${borrower.id}',
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        await saveBorrower(borrower);
        return;
      }
      throw _mapError(error, 'Unable to verify borrower');
    }
  }

  Future<void> saveBorrower(Borrower borrower) async {
    try {
      await _dio.post<void>(ApiEndpoints.borrowers, data: borrower.toJson());
    } on DioException catch (error) {
      throw _mapError(error, 'Unable to create borrower');
    }
  }

  Future<List<Borrower>> getBorrowers({String? query}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.borrowers,
        queryParameters: {
          if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        },
      );
      final rows = response.data ?? const <dynamic>[];
      return rows
          .map(
            (row) => Borrower.fromJson(
              Map<String, dynamic>.from(row as Map<dynamic, dynamic>),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw _mapError(error, 'Unable to load borrowers');
    } on FormatException catch (error) {
      throw RemoteBorrowerException(
        'Invalid borrower response: ${error.message}',
        isRetryable: false,
      );
    } on TypeError catch (error) {
      throw RemoteBorrowerException(
        'Invalid borrower response: $error',
        isRetryable: false,
      );
    }
  }

  Future<void> updateBorrower(Borrower borrower) async {
    try {
      await _dio.put<void>(
        '${ApiEndpoints.borrowers}/${borrower.id}',
        data: borrower.toJson(),
      );
    } on DioException catch (error) {
      throw _mapError(error, 'Unable to update borrower');
    }
  }

  Future<void> deleteBorrower(String id) async {
    try {
      await _dio.delete<void>('${ApiEndpoints.borrowers}/$id');
    } on DioException catch (error) {
      throw _mapError(error, 'Unable to delete borrower');
    }
  }

  RemoteBorrowerException _mapError(DioException error, String fallback) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;
    final detail = responseData is Map<String, dynamic>
        ? responseData['detail']
        : null;
    final message = _formatDetail(detail) ?? error.message ?? fallback;
    return RemoteBorrowerException(
      message,
      statusCode: statusCode,
      isRetryable: statusCode == null || statusCode >= 500,
    );
  }

  String? _formatDetail(Object? detail) {
    if (detail is String) return detail;
    if (detail is! List) return null;

    final messages = detail.whereType<Map<Object?, Object?>>().map((item) {
      final location = item['loc'];
      final field = location is List && location.isNotEmpty
          ? location.last.toString()
          : 'request';
      final reason = item['msg']?.toString() ?? 'is invalid';
      return '$field: $reason';
    }).toList();
    return messages.isEmpty ? null : messages.join('\n');
  }
}

final remoteBorrowerRepositoryProvider = Provider<RemoteBorrowerRepository>((
  ref,
) {
  return RemoteBorrowerRepository(ref.watch(apiClientProvider));
});
