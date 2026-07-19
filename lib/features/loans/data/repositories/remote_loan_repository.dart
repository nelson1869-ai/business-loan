import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/models/loan.dart';
import '../models/loan_create_request.dart';

/// A readable loan API failure with retry guidance for future offline support.
class RemoteLoanException implements Exception {
  /// Creates a mapped loan repository exception.
  const RemoteLoanException(
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

/// Performs authenticated loan operations against FastAPI.
class RemoteLoanRepository {
  /// Creates a repository backed by the shared authenticated client.
  RemoteLoanRepository(this._dio);

  final Dio _dio;

  /// Creates a loan and returns its backend-generated installment schedule.
  Future<Loan> createLoan(LoanCreateRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.loans,
        data: request.toJson(),
      );
      return _parseLoan(response.data, 'Loan creation response was empty');
    } on DioException catch (error) {
      throw _mapError(error, 'Unable to create loan');
    } on FormatException catch (error) {
      throw RemoteLoanException(error.message, isRetryable: false);
    } on TypeError catch (error) {
      throw RemoteLoanException(
        'Invalid loan response: $error',
        isRetryable: false,
      );
    }
  }

  /// Lists loans, optionally restricted to one borrower and account status.
  Future<List<Loan>> getLoans({String? borrowerId, String? status}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.loans,
        queryParameters: <String, dynamic>{
          'borrowerId': ?borrowerId,
          'status': ?status,
        },
      );
      final rows = response.data ?? const <dynamic>[];
      return rows
          .map<Loan>((dynamic row) {
            if (row is! Map<dynamic, dynamic>) {
              throw const FormatException(
                'Loan list item must be a JSON object',
              );
            }
            return Loan.fromJson(Map<String, dynamic>.from(row));
          })
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapError(error, 'Unable to load loans');
    } on FormatException catch (error) {
      throw RemoteLoanException(error.message, isRetryable: false);
    } on TypeError catch (error) {
      throw RemoteLoanException(
        'Invalid loan response: $error',
        isRetryable: false,
      );
    }
  }

  /// Loads one loan with its complete persisted installment schedule.
  Future<Loan> getLoan(String loanId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.loans}/$loanId',
      );
      return _parseLoan(response.data, 'Loan detail response was empty');
    } on DioException catch (error) {
      throw _mapError(error, 'Unable to load loan');
    } on FormatException catch (error) {
      throw RemoteLoanException(error.message, isRetryable: false);
    } on TypeError catch (error) {
      throw RemoteLoanException(
        'Invalid loan response: $error',
        isRetryable: false,
      );
    }
  }

  Loan _parseLoan(Map<String, dynamic>? data, String emptyMessage) {
    if (data == null) throw FormatException(emptyMessage);
    return Loan.fromJson(data);
  }

  RemoteLoanException _mapError(DioException error, String fallback) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;
    final detail = responseData is Map<String, dynamic>
        ? responseData['detail']
        : null;
    final message = _formatDetail(detail) ?? error.message ?? fallback;
    return RemoteLoanException(
      message,
      statusCode: statusCode,
      isRetryable: statusCode == null || statusCode >= 500,
    );
  }

  String? _formatDetail(Object? detail) {
    if (detail is String) return detail;
    if (detail is! List<dynamic>) return null;
    final messages = detail
        .whereType<Map<Object?, Object?>>()
        .map((item) {
          final location = item['loc'];
          final field = location is List<dynamic> && location.isNotEmpty
              ? location.last.toString()
              : 'request';
          return '$field: ${item['msg']?.toString() ?? 'is invalid'}';
        })
        .toList(growable: false);
    return messages.isEmpty ? null : messages.join('\n');
  }
}

/// Authenticated remote loan repository used by presentation providers.
final remoteLoanRepositoryProvider = Provider<RemoteLoanRepository>((ref) {
  return RemoteLoanRepository(ref.watch(apiClientProvider));
});
