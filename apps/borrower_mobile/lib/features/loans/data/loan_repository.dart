import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/features/loans/data/loan_local_cache.dart';
import 'package:borrower_mobile/features/loans/models/borrower_loan.dart';

class LoanRepository {
  final ApiClient apiClient;
  final LoanLocalCache localCache;

  LoanRepository({
    required this.apiClient,
    LoanLocalCache? localCache,
  }) : localCache = localCache ?? LoanLocalCache();

  Future<BorrowerLoanListResponse> getLoans({
    required String borrowerAccountId,
    String? status,
    int offset = 0,
    int limit = 20,
  }) async {
    if (borrowerAccountId.trim().isEmpty) {
      throw ArgumentError.value(
        borrowerAccountId,
        'borrowerAccountId',
        'must not be empty',
      );
    }
    try {
      final queryParams = <String, String>{
        'offset': offset.toString(),
        'limit': limit.toString(),
      };
      if (status != null &&
          status.isNotEmpty &&
          status.toLowerCase() != 'all') {
        queryParams['status'] = status.toLowerCase();
      }

      final uri = Uri(
        path: '/api/v1/client/loans',
        queryParameters: queryParams,
      ).toString();

      final json = await apiClient.get(uri);
      final response = BorrowerLoanListResponse.fromJson(json);
      await localCache.saveCachedLoansList(
        borrowerAccountId,
        response,
        statusFilter: status,
        offset: offset,
        limit: limit,
      );
      return response;
    } catch (e) {
      final cached = await localCache.getCachedLoansList(
        borrowerAccountId,
        statusFilter: status,
        offset: offset,
        limit: limit,
      );
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<BorrowerLoanDetail> getLoanDetail({
    required String borrowerAccountId,
    required String loanId,
  }) async {
    if (borrowerAccountId.trim().isEmpty) {
      throw ArgumentError.value(
        borrowerAccountId,
        'borrowerAccountId',
        'must not be empty',
      );
    }
    try {
      final json = await apiClient.get('/api/v1/client/loans/$loanId');
      final detail = BorrowerLoanDetail.fromJson(json, isFromCache: false);
      await localCache.saveCachedLoanDetail(borrowerAccountId, detail);
      return detail;
    } catch (e) {
      final cached =
          await localCache.getCachedLoanDetail(borrowerAccountId, loanId);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<BorrowerInstallmentSchedule> getLoanSchedule({
    required String borrowerAccountId,
    required String loanId,
  }) async {
    if (borrowerAccountId.trim().isEmpty) {
      throw ArgumentError.value(
        borrowerAccountId,
        'borrowerAccountId',
        'must not be empty',
      );
    }
    try {
      final json =
          await apiClient.get('/api/v1/client/loans/$loanId/schedule');
      final schedule =
          BorrowerInstallmentSchedule.fromJson(json, isFromCache: false);
      await localCache.saveCachedLoanSchedule(borrowerAccountId, schedule);
      return schedule;
    } catch (e) {
      final cached =
          await localCache.getCachedLoanSchedule(borrowerAccountId, loanId);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }
}
