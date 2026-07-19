// Third-party packages
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Core network
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

// Feature domain
import '../../domain/models/borrower.dart';

/// A meaningful remote borrower failure with retry guidance.
class RemoteBorrowerException implements Exception {
  /// Creates a remote repository exception.
  const RemoteBorrowerException(
    this.message, {
    this.statusCode,
    required this.isRetryable,
  });

  /// Human-readable failure description.
  final String message;

  /// HTTP status code when the server returned a response.
  final int? statusCode;

  /// Whether storing the operation for later retry is appropriate.
  final bool isRetryable;

  @override
  String toString() => message;
}

/// Performs borrower CRUD operations against the FastAPI backend.
class RemoteBorrowerRepository {
  /// Creates a repository backed by the shared [Dio] client.
  RemoteBorrowerRepository(this._dio);

  final Dio _dio;

  /// Creates [borrower] remotely.
  Future<void> saveBorrower(Borrower borrower) async {
    try {
      await _dio.post<void>(ApiEndpoints.borrowers, data: borrower.toJson());
    } on DioException catch (error) {
      throw _mapError(error, 'Unable to create borrower');
    }
  }

  /// Returns all borrowers available to the authenticated user.
  Future<List<Borrower>> getBorrowers() async {
    try {
      final response = await _dio.get<List<dynamic>>(ApiEndpoints.borrowers);
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

  /// Replaces the remote values for [borrower].
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

  /// Soft-deletes the remote borrower identified by [id].
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

/// Remote borrower repository used by application state notifiers.
final remoteBorrowerRepositoryProvider = Provider<RemoteBorrowerRepository>((
  ref,
) {
  return RemoteBorrowerRepository(ref.watch(apiClientProvider));
});
