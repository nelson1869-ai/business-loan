import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:borrower_mobile/features/loans/models/borrower_loan.dart';

class LoanLocalCache {
  final FlutterSecureStorage _storage;

  LoanLocalCache({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  String _loansListKey(String borrowerAccountId, String? statusFilter) {
    final status = statusFilter?.toLowerCase() ?? 'all';
    return 'cached_loans_list_${borrowerAccountId}_$status';
  }

  String _loanDetailKey(String borrowerAccountId, String loanId) {
    return 'cached_loan_detail_${borrowerAccountId}_$loanId';
  }

  Future<BorrowerLoanListResponse?> getCachedLoansList(
    String borrowerAccountId, {
    String? statusFilter,
  }) async {
    try {
      final key = _loansListKey(borrowerAccountId, statusFilter);
      final rawJson = await _storage.read(key: key);
      if (rawJson == null || rawJson.isEmpty) {
        return null;
      }
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return BorrowerLoanListResponse.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedLoansList(
    String borrowerAccountId,
    BorrowerLoanListResponse response, {
    String? statusFilter,
  }) async {
    try {
      final key = _loansListKey(borrowerAccountId, statusFilter);
      final rawJson = jsonEncode(response.toJson());
      await _storage.write(key: key, value: rawJson);
    } catch (_) {}
  }

  Future<BorrowerLoanDetail?> getCachedLoanDetail(
    String borrowerAccountId,
    String loanId,
  ) async {
    try {
      final key = _loanDetailKey(borrowerAccountId, loanId);
      final rawJson = await _storage.read(key: key);
      if (rawJson == null || rawJson.isEmpty) {
        return null;
      }
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return BorrowerLoanDetail.fromJson(map, isFromCache: true);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedLoanDetail(
    String borrowerAccountId,
    BorrowerLoanDetail detail,
  ) async {
    try {
      final key = _loanDetailKey(borrowerAccountId, detail.id);
      final rawJson = jsonEncode(detail.toJson());
      await _storage.write(key: key, value: rawJson);
    } catch (_) {}
  }

  Future<void> clearAllCachedLoans() async {
    try {
      final allKeys = await _storage.readAll();
      for (final key in allKeys.keys) {
        if (key.startsWith('cached_loans_list_') ||
            key.startsWith('cached_loan_detail_')) {
          await _storage.delete(key: key);
        }
      }
    } catch (_) {}
  }
}
