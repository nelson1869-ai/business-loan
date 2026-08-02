import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:borrower_mobile/features/payments/models/borrower_payment.dart';
import 'package:borrower_mobile/features/payments/receipt_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/features/payments/data/payment_local_cache.dart';
import 'package:borrower_mobile/features/payments/data/payment_repository.dart';
import 'package:borrower_mobile/features/payments/providers/payments_provider.dart';

class FakePaymentApiClient implements ApiClient {
  final Map<String, dynamic> historyResponse;
  final Map<String, dynamic> receiptResponse;

  FakePaymentApiClient({
    required this.historyResponse,
    required this.receiptResponse,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) {
      final String path = invocation.positionalArguments.first as String;
      if (path.contains('/receipt')) {
        return Future.value(receiptResponse);
      }
      return Future.value(historyResponse);
    }
    return super.noSuchMethod(invocation);
  }
}

class FakePaymentLocalCache implements PaymentLocalCache {
  final Map<String, dynamic> _store = {};

  @override
  Future<BorrowerPaymentHistory?> getCachedLoanPayments(
    String borrowerAccountId,
    String loanId,
  ) async {
    return _store['pmts_${borrowerAccountId}_$loanId']
        as BorrowerPaymentHistory?;
  }

  @override
  Future<void> saveCachedLoanPayments(
    String borrowerAccountId,
    String loanId,
    BorrowerPaymentHistory history,
  ) async {
    _store['pmts_${borrowerAccountId}_$loanId'] = history;
  }

  @override
  Future<BorrowerReceiptDetail?> getCachedReceipt(
    String borrowerAccountId,
    String paymentId,
  ) async {
    return _store['rcpt_${borrowerAccountId}_$paymentId']
        as BorrowerReceiptDetail?;
  }

  @override
  Future<void> saveCachedReceipt(
    String borrowerAccountId,
    BorrowerReceiptDetail receipt,
  ) async {
    _store['rcpt_${borrowerAccountId}_${receipt.paymentId}'] = receipt;
  }

  @override
  Future<void> clearAllCachedPayments() async {
    _store.clear();
  }
}

void main() {
  final sampleHistoryJson = {
    'totalCount': 1,
    'items': [
      {
        'id': 'pmt-100',
        'receiptNumber': 'RCPT-ABCD12345678',
        'effectiveDate': '2026-08-01T00:00:00.000',
        'amount': 1020.00,
        'entryType': 'payment',
        'status': 'posted',
        'createdAt': '2026-08-01T12:00:00.000',
      }
    ],
  };

  final sampleReceiptJson = {
    'receiptNumber': 'RCPT-ABCD12345678',
    'paymentId': 'pmt-100',
    'loanId': 'loan-123',
    'loanReference': 'LN-2026-000123',
    'paymentDate': '2026-08-01T00:00:00.000',
    'amountReceived': 1020.00,
    'principalPaid': 1000.00,
    'interestPaid': 20.00,
    'penaltyPaid': 0.00,
    'unappliedCredit': 0.00,
    'remainingBalance': 4000.00,
    'entryType': 'payment',
    'status': 'posted',
    'recordedAt': '2026-08-01T12:00:00.000',
  };

  group('BorrowerPayment Models Unit Tests', () {
    test('BorrowerPaymentListItem.fromJson parses correct fields', () {
      final rawItems = sampleHistoryJson['items'] as List<dynamic>;
      final item = BorrowerPaymentListItem.fromJson(
        rawItems[0] as Map<String, dynamic>,
      );

      expect(item.id, equals('pmt-100'));
      expect(item.receiptNumber, equals('RCPT-ABCD12345678'));
      expect(item.amount, equals(1020.00));
      expect(item.entryType, equals('payment'));
      expect(item.status, equals('posted'));
    });

    test('BorrowerReceiptDetail.fromJson parses breakdown fields', () {
      final receipt = BorrowerReceiptDetail.fromJson(sampleReceiptJson);

      expect(receipt.receiptNumber, equals('RCPT-ABCD12345678'));
      expect(receipt.amountReceived, equals(1020.00));
      expect(receipt.principalPaid, equals(1000.00));
      expect(receipt.interestPaid, equals(20.00));
      expect(receipt.remainingBalance, equals(4000.00));
    });

    test('toJson cycle preserves data integrity', () {
      final receipt = BorrowerReceiptDetail.fromJson(sampleReceiptJson);
      final encoded = jsonEncode(receipt.toJson());
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = BorrowerReceiptDetail.fromJson(decoded);

      expect(restored.receiptNumber, equals(receipt.receiptNumber));
      expect(restored.principalPaid, equals(receipt.principalPaid));
    });
  });

  group('ReceiptModal Widget Tests', () {
    testWidgets('renders digital receipt allocation breakdown correctly',
        (tester) async {
      final api = FakePaymentApiClient(
        historyResponse: sampleHistoryJson,
        receiptResponse: sampleReceiptJson,
      );
      final cache = FakePaymentLocalCache();
      final repo = PaymentRepository(apiClient: api, localCache: cache);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentReceiptNotifierProvider('pmt-100').overrideWith(
              (ref) => PaymentReceiptNotifier(
                repository: repo,
                borrowerAccountId: 'account-123',
                paymentId: 'pmt-100',
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ReceiptModal(paymentId: 'pmt-100'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Official Receipt'), findsOneWidget);
      expect(find.text('RCPT-ABCD12345678'), findsOneWidget);
      expect(find.text('₱ 1,020.00'), findsOneWidget);
      expect(find.text('₱ 1,000.00'), findsOneWidget);
      expect(find.text('₱ 20.00'), findsOneWidget);
      expect(find.text('₱ 4,000.00'), findsOneWidget);
      expect(find.text('POSTED'), findsOneWidget);
    });
  });
}
