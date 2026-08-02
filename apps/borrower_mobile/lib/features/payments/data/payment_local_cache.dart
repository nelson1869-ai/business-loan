import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:borrower_mobile/features/payments/models/borrower_payment.dart';

class PaymentLocalCache {
  final FlutterSecureStorage _storage;

  PaymentLocalCache({FlutterSecureStorage? storage})
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

  String _paymentsListKey(String borrowerAccountId, String loanId) {
    final accountId = _requireAccountId(borrowerAccountId);
    if (loanId.trim().isEmpty) {
      throw ArgumentError.value(loanId, 'loanId', 'must not be empty');
    }
    return 'cached_payments_${accountId}_${loanId.trim()}';
  }

  String _receiptKey(String borrowerAccountId, String paymentId) {
    final accountId = _requireAccountId(borrowerAccountId);
    if (paymentId.trim().isEmpty) {
      throw ArgumentError.value(paymentId, 'paymentId', 'must not be empty');
    }
    return 'cached_receipt_${accountId}_${paymentId.trim()}';
  }

  Future<BorrowerPaymentHistory?> getCachedLoanPayments(
    String borrowerAccountId,
    String loanId,
  ) async {
    final key = _paymentsListKey(borrowerAccountId, loanId);
    try {
      final rawJson = await _storage.read(key: key);
      if (rawJson == null || rawJson.isEmpty) {
        return null;
      }
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return BorrowerPaymentHistory.fromJson(map, isFromCache: true);
    } catch (_) {
      await _storage.delete(key: key).catchError((_) {});
      return null;
    }
  }

  Future<void> saveCachedLoanPayments(
    String borrowerAccountId,
    String loanId,
    BorrowerPaymentHistory history,
  ) async {
    final key = _paymentsListKey(borrowerAccountId, loanId);
    final rawJson = jsonEncode(history.toJson());
    await _storage.write(key: key, value: rawJson);
  }

  Future<BorrowerReceiptDetail?> getCachedReceipt(
    String borrowerAccountId,
    String paymentId,
  ) async {
    final key = _receiptKey(borrowerAccountId, paymentId);
    try {
      final rawJson = await _storage.read(key: key);
      if (rawJson == null || rawJson.isEmpty) {
        return null;
      }
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return BorrowerReceiptDetail.fromJson(map, isFromCache: true);
    } catch (_) {
      await _storage.delete(key: key).catchError((_) {});
      return null;
    }
  }

  Future<void> saveCachedReceipt(
    String borrowerAccountId,
    BorrowerReceiptDetail receipt,
  ) async {
    final key = _receiptKey(borrowerAccountId, receipt.paymentId);
    final rawJson = jsonEncode(receipt.toJson());
    await _storage.write(key: key, value: rawJson);
  }

  Future<void> clearAllCachedPayments() async {
    try {
      final allKeys = await _storage.readAll();
      for (final key in allKeys.keys) {
        if (key.startsWith('cached_payments_') ||
            key.startsWith('cached_receipt_')) {
          await _storage.delete(key: key);
        }
      }
    } catch (_) {}
  }
}
