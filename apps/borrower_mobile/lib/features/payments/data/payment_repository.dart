import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/features/payments/data/payment_local_cache.dart';
import 'package:borrower_mobile/features/payments/models/borrower_payment.dart';

class PaymentRepository {
  final ApiClient apiClient;
  final PaymentLocalCache localCache;

  PaymentRepository({
    required this.apiClient,
    PaymentLocalCache? localCache,
  }) : localCache = localCache ?? PaymentLocalCache();

  Future<BorrowerPaymentHistory> getLoanPayments({
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
      final json = await apiClient.get('/api/v1/client/loans/$loanId/payments');
      final history = BorrowerPaymentHistory.fromJson(json, isFromCache: false);
      await localCache.saveCachedLoanPayments(
          borrowerAccountId, loanId, history);
      return history;
    } catch (e) {
      final cached =
          await localCache.getCachedLoanPayments(borrowerAccountId, loanId);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<BorrowerReceiptDetail> getPaymentReceipt({
    required String borrowerAccountId,
    required String paymentId,
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
          await apiClient.get('/api/v1/client/payments/$paymentId/receipt');
      final receipt = BorrowerReceiptDetail.fromJson(json, isFromCache: false);
      await localCache.saveCachedReceipt(borrowerAccountId, receipt);
      return receipt;
    } catch (e) {
      final cached =
          await localCache.getCachedReceipt(borrowerAccountId, paymentId);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<String> fetchAiExplanation(String receiptId) async {
    final response = await apiClient.post(
      '/api/v1/client/me/receipts/$receiptId/explanation',
    );
    return response['aiExplanation'] as String? ?? 'No explanation generated';
  }
}
