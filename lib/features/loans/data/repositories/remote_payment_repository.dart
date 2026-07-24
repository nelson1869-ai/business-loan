// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/models/payment.dart';
import 'local_loan_repository.dart';
import 'remote_loan_repository.dart';

/// Calls the authenticated payment endpoints owned by FastAPI.
class RemotePaymentRepository {
  RemotePaymentRepository(this._dio, {LocalLoanRepository? localRepo})
    : _localRepo = localRepo;

  final Dio _dio;
  final LocalLoanRepository? _localRepo;

  Future<PaymentPreview> preview({
    required String loanId,
    required String amount,
    required String effectiveDate,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.loanPayments(loanId)}/preview',
        data: <String, dynamic>{
          'amount': amount,
          'effectiveDate': effectiveDate,
        },
      );
      return PaymentPreview.fromJson(_requiredMap(response.data));
    } on DioException catch (error) {
      throw _mapError(error, 'Unable to preview payment');
    } on FormatException catch (error) {
      throw RemoteLoanException(error.message, isRetryable: false);
    }
  }

  Future<LoanPayment> confirm({
    required String loanId,
    required String requestId,
    required String amount,
    required String effectiveDate,
    String? note,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.loanPayments(loanId),
        data: <String, dynamic>{
          'requestId': requestId,
          'amount': amount,
          'effectiveDate': effectiveDate,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
      final payment = LoanPayment.fromJson(_requiredMap(response.data));
      await _localRepo?.savePayment(payment);
      return payment;
    } on DioException catch (error) {
      throw _mapError(error, 'Unable to record payment');
    } on FormatException catch (error) {
      throw RemoteLoanException(error.message, isRetryable: false);
    }
  }

  Future<List<LoanPayment>> history(String loanId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.loanPayments(loanId),
      );
      final payments = (response.data ?? const <dynamic>[])
          .map((dynamic row) {
            if (row is! Map) {
              throw const FormatException('Payment must be an object');
            }
            return LoanPayment.fromJson(Map<String, dynamic>.from(row));
          })
          .toList(growable: false);
      await _localRepo?.savePayments(loanId, payments);
      return payments;
    } on DioException catch (error) {
      final local = _localRepo;
      if (local != null) {
        final cached = await local.getPayments(loanId);
        if (cached.isNotEmpty) return cached;
      }
      throw _mapError(error, 'Unable to load payment history');
    } on FormatException catch (error) {
      throw RemoteLoanException(error.message, isRetryable: false);
    }
  }

  /// Reverses one complete payment while preserving both ledger entries.
  Future<LoanPayment> reverse({
    required String loanId,
    required String paymentId,
    required String requestId,
    required String effectiveDate,
    required String reason,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.loanPayments(loanId)}/$paymentId/reversal',
        data: <String, dynamic>{
          'requestId': requestId,
          'effectiveDate': effectiveDate,
          'reason': reason.trim(),
        },
      );
      final payment = LoanPayment.fromJson(_requiredMap(response.data));
      await _localRepo?.savePayment(payment);
      return payment;
    } on DioException catch (error) {
      throw _mapError(error, 'Unable to reverse payment');
    } on FormatException catch (error) {
      throw RemoteLoanException(error.message, isRetryable: false);
    }
  }

  Map<String, dynamic> _requiredMap(Map<String, dynamic>? data) {
    if (data == null) throw const FormatException('Payment response was empty');
    return data;
  }

  RemoteLoanException _mapError(DioException error, String fallback) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final detail = data is Map ? data['detail'] : null;
    return RemoteLoanException(
      detail is String ? detail : error.message ?? fallback,
      statusCode: statusCode,
      isRetryable: statusCode == null || statusCode >= 500,
    );
  }
}

final remotePaymentRepositoryProvider = Provider<RemotePaymentRepository>((
  ref,
) {
  return RemotePaymentRepository(
    ref.watch(apiClientProvider),
    localRepo: ref.watch(localLoanRepositoryProvider),
  );
});
