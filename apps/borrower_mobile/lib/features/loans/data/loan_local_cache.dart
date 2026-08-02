import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:borrower_mobile/features/loans/models/borrower_loan.dart';

class LoanLocalCache {
  final FlutterSecureStorage _storage;

  LoanLocalCache({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  String _requireAccountId(String borrowerAccountId) {
    final accountId = borrowerAccountId.trim();
    if (accountId.isEmpty) {
      throw ArgumentError.value(
        borrowerAccountId,
        'borrowerAccountId',
        'must not be empty',
      );
    }
    return accountId;
  }

  String _loansListKey(
    String borrowerAccountId,
    String? statusFilter,
    int offset,
    int limit,
  ) {
    final accountId = _requireAccountId(borrowerAccountId);
    final status = statusFilter?.toLowerCase() ?? 'all';
    return 'cached_loans_list_${accountId}_${status}_${offset}_$limit';
  }

  String _loanDetailKey(String borrowerAccountId, String loanId) {
    final accountId = _requireAccountId(borrowerAccountId);
    if (loanId.trim().isEmpty) {
      throw ArgumentError.value(loanId, 'loanId', 'must not be empty');
    }
    return 'cached_loan_detail_${accountId}_${loanId.trim()}';
  }

  Future<BorrowerLoanListResponse?> getCachedLoansList(
    String borrowerAccountId, {
    String? statusFilter,
    int offset = 0,
    int limit = 20,
  }) async {
    final key = _loansListKey(
      borrowerAccountId,
      statusFilter,
      offset,
      limit,
    );
    try {
      final rawJson = await _storage.read(key: key);
      if (rawJson == null || rawJson.isEmpty) {
        return null;
      }
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return BorrowerLoanListResponse.fromJson(map);
    } catch (_) {
      await _storage.delete(key: key).catchError((_) {});
      return null;
    }
  }

  Future<void> saveCachedLoansList(
    String borrowerAccountId,
    BorrowerLoanListResponse response, {
    String? statusFilter,
    int offset = 0,
    int limit = 20,
  }) async {
    final key = _loansListKey(borrowerAccountId, statusFilter, offset, limit);
    final rawJson = jsonEncode(response.toJson());
    await _storage.write(key: key, value: rawJson);
  }

  Future<BorrowerLoanDetail?> getCachedLoanDetail(
    String borrowerAccountId,
    String loanId,
  ) async {
    final key = _loanDetailKey(borrowerAccountId, loanId);
    try {
      final rawJson = await _storage.read(key: key);
      if (rawJson == null || rawJson.isEmpty) {
        return null;
      }
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return BorrowerLoanDetail.fromJson(map, isFromCache: true);
    } catch (_) {
      await _storage.delete(key: key).catchError((_) {});
      return null;
    }
  }

  Future<void> saveCachedLoanDetail(
    String borrowerAccountId,
    BorrowerLoanDetail detail,
  ) async {
    final key = _loanDetailKey(borrowerAccountId, detail.id);
    final rawJson = jsonEncode(detail.toJson());
    await _storage.write(key: key, value: rawJson);
  }

  String _loanScheduleKey(String borrowerAccountId, String loanId) {
    final accountId = _requireAccountId(borrowerAccountId);
    if (loanId.trim().isEmpty) {
      throw ArgumentError.value(loanId, 'loanId', 'must not be empty');
    }
    return 'cached_loan_schedule_${accountId}_${loanId.trim()}';
  }

  Future<BorrowerInstallmentSchedule?> getCachedLoanSchedule(
    String borrowerAccountId,
    String loanId,
  ) async {
    final key = _loanScheduleKey(borrowerAccountId, loanId);
    try {
      final rawJson = await _storage.read(key: key);
      if (rawJson == null || rawJson.isEmpty) {
        return null;
      }
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return BorrowerInstallmentSchedule.fromJson(map, isFromCache: true);
    } catch (_) {
      await _storage.delete(key: key).catchError((_) {});
      return null;
    }
  }

  Future<void> saveCachedLoanSchedule(
    String borrowerAccountId,
    BorrowerInstallmentSchedule schedule,
  ) async {
    final key = _loanScheduleKey(borrowerAccountId, schedule.loanId);
    final rawJson = jsonEncode(schedule.toJson());
    await _storage.write(key: key, value: rawJson);
  }

  Future<void> clearAllCachedLoans() async {
    try {
      final allKeys = await _storage.readAll();
      for (final key in allKeys.keys) {
        if (key.startsWith('cached_loans_list_') ||
            key.startsWith('cached_loan_detail_') ||
            key.startsWith('cached_loan_schedule_')) {
          await _storage.delete(key: key);
        }
      }
    } catch (_) {}
  }
}
