import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/offline_sync_service.dart';
import '../models/loan_explanation.dart';
import '../../domain/models/loan.dart';
import '../models/loan_create_request.dart';
import '../models/loan_quote.dart';
import 'local_loan_repository.dart';

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

/// Performs authenticated loan operations against FastAPI, with automatic
/// fallback to the local SQLite cache when offline.
class RemoteLoanRepository {
  RemoteLoanRepository(this._dio, {this._localRepo, this._syncService});

  final Dio _dio;
  final LocalLoanRepository? _localRepo;
  final OfflineSyncService? _syncService;

  /// Calculates a quote without creating a loan or writing local data.
  Future<LoanQuote> calculateQuote({
    required String principal,
    required String monthlyRate,
    required int termMonths,
    required int paymentsPerMonth,
    required String firstDueDate,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.loanQuote,
        data: <String, dynamic>{
          'originalPrincipal': principal,
          'monthlyRate': monthlyRate,
          'termMonths': termMonths,
          'paymentsPerMonth': paymentsPerMonth,
          'firstDueDate': firstDueDate,
        },
      );
      final json = response.data;
      if (json == null) throw const FormatException('Empty quote response');
      return LoanQuote.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error, 'Unable to calculate loan quote');
    } on FormatException catch (error) {
      throw RemoteLoanException(error.message, isRetryable: false);
    }
  }

  /// Creates a loan.  On success the result is cached locally.  On a retryable
  /// network failure the loan is saved to the local cache and enqueued for
  /// background sync.
  Future<Loan> createLoan(LoanCreateRequest request) async {
    final payload = request.toJson();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.loans,
        data: payload,
      );
      final json = response.data;
      if (json == null) {
        throw const FormatException('Empty server response creating loan');
      }
      final loan = Loan.fromJson(json);
      await _localRepo?.saveLoan(loan);
      return loan;
    } on DioException catch (error) {
      final mapped = _mapError(error, 'Unable to create loan');
      if (mapped.isRetryable && _localRepo != null && _syncService != null) {
        final fallbackLoan = _offlineLoan(request);
        await _localRepo.saveLoan(fallbackLoan);
        await _syncService.enqueue(
          endpoint: ApiEndpoints.loans,
          method: 'POST',
          payload: payload,
        );
        return fallbackLoan;
      }
      throw mapped;
    }
  }

  /// Creates an online-only draft for maker-checker processing.
  Future<Loan> createDraft(LoanCreateRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.loanDrafts,
        data: request.toJson(),
      );
      final loan = _parseLoan(response.data, 'Draft response was empty');
      await _localRepo?.saveLoan(loan);
      return loan;
    } on DioException catch (error) {
      throw _mapError(error, 'Internet is required to create a loan draft');
    }
  }

  /// Applies one backend-authorized online-only lifecycle transition.
  Future<Loan> transition(String loanId, String action) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.loanWorkflow(loanId, action),
      );
      final data = response.data;
      if (data == null) throw const FormatException('Empty loan response');
      Loan loan;
      if (data.containsKey('originalPrincipal') ||
          data.containsKey('original_principal')) {
        loan = Loan.fromJson(data);
      } else {
        loan = await getLoan(loanId);
      }
      await _localRepo?.saveLoan(loan);
      return loan;
    } on DioException catch (error) {
      throw _mapError(error, 'Unable to update the loan workflow');
    } on FormatException catch (error) {
      throw RemoteLoanException(error.message, isRetryable: false);
    } on TypeError catch (error) {
      throw RemoteLoanException(
        'Invalid loan response: $error',
        isRetryable: false,
      );
    }
  }

  /// Lists loans, optionally restricted to one borrower.
  /// On network failure falls back to the local cache.
  Future<List<Loan>> getLoans({String? borrowerId, String? status}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (borrowerId != null) queryParams['borrowerId'] = borrowerId;
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.loans,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final rows = response.data ?? const <dynamic>[];
      final loans = rows
          .map<Loan>((dynamic row) {
            if (row is! Map<dynamic, dynamic>) {
              throw const FormatException(
                'Loan list item must be a JSON object',
              );
            }
            return Loan.fromJson(Map<String, dynamic>.from(row));
          })
          .toList(growable: false);

      if (borrowerId == null && status == null) {
        await _localRepo?.syncLoans(loans);
      } else {
        await _localRepo?.saveLoans(loans);
      }
      return loans;
    } on DioException catch (error) {
      if (_localRepo != null) {
        final cached = await _localRepo.getLoans(borrowerId: borrowerId);
        if (cached.isNotEmpty) return cached;
      }
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
  /// On network failure falls back to the local cache.
  Future<Loan> getLoan(String loanId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.loans}/$loanId',
      );
      final loan = _parseLoan(response.data, 'Loan detail response was empty');
      await _localRepo?.saveLoan(loan);
      return loan;
    } on DioException catch (error) {
      if (_localRepo != null) {
        final cached = await _localRepo.getLoan(loanId);
        if (cached != null) return cached;
      }
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

  /// Requests a privacy-minimized explanation; no borrower data leaves Flutter.
  Future<LoanExplanation> explainLoan(String loanId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.loanExplanation(loanId),
        options: Options(receiveTimeout: const Duration(seconds: 70)),
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty loan explanation response');
      }
      return LoanExplanation.fromJson(data);
    } on DioException catch (error) {
      throw _mapError(error, 'Unable to explain this loan right now');
    } on FormatException catch (error) {
      throw RemoteLoanException(error.message, isRetryable: false);
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

  /// Builds a minimal offline loan stub so the UI can show it immediately
  /// while the real creation is deferred.
  Loan _offlineLoan(LoanCreateRequest request) => Loan(
    id: request.requestId,
    requestId: request.requestId,
    borrowerId: request.borrowerId,
    createdByUserId: '',
    originalPrincipal: request.originalPrincipal,
    outstandingPrincipal: request.originalPrincipal,
    monthlyRate: request.monthlyRate,
    termMonths: request.termMonths,
    paymentsPerMonth: request.paymentsPerMonth,
    numberOfPayments: request.termMonths * request.paymentsPerMonth,
    regularPaymentAmount: '',
    calculationMethod: 'fixed_periodic_reducing_balance',
    startDate: request.startDate,
    firstDueDate: request.firstDueDate,
    finalDueDate: '',
    status: 'Pending',
    createdAt: DateTime.now().toUtc().toIso8601String(),
  );
}

/// Authenticated remote loan repository used by presentation providers.
final remoteLoanRepositoryProvider = Provider<RemoteLoanRepository>((ref) {
  return RemoteLoanRepository(
    ref.watch(apiClientProvider),
    localRepo: ref.watch(localLoanRepositoryProvider),
    syncService: ref.watch(offlineSyncServiceProvider),
  );
});
