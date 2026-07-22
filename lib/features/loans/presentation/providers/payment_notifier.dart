import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/offline_sync_service.dart';
import '../../data/repositories/local_loan_repository.dart';
import '../../data/repositories/remote_loan_repository.dart';
import '../../data/repositories/remote_payment_repository.dart';
import '../../domain/models/payment.dart';

class PaymentState {
  final PaymentPreview? preview;
  final bool working;
  final String? error;

  const PaymentState({this.preview, this.working = false, this.error});
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  PaymentNotifier(this._paymentRepository, {this._localRepo, this._syncService})
    : super(const PaymentState());

  final RemotePaymentRepository _paymentRepository;
  final LocalLoanRepository? _localRepo;
  final OfflineSyncService? _syncService;

  void resetPreview() {
    state = PaymentState(preview: null);
  }

  String? _requestId;
  String? _fingerprint;
  String? _reversalRequestId;
  String? _reversalFingerprint;

  Future<void> loadPreview({
    required String loanId,
    required String amount,
    required String effectiveDate,
  }) async {
    state = PaymentState(working: true);
    try {
      final preview = await _paymentRepository.preview(
        loanId: loanId,
        amount: amount,
        effectiveDate: effectiveDate,
      );
      state = PaymentState(preview: preview);
    } on RemoteLoanException catch (e) {
      state = PaymentState(error: e.message);
    }
  }

  Future<void> confirm({
    required String loanId,
    required String amount,
    required String effectiveDate,
    required String note,
  }) async {
    final fingerprint = '$amount|$effectiveDate|$note';
    if (_fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      _requestId = const Uuid().v4();
    }
    state = PaymentState(preview: state.preview, working: true);
    try {
      final payment = await _paymentRepository.confirm(
        loanId: loanId,
        requestId: _requestId!,
        amount: amount,
        effectiveDate: effectiveDate,
        note: note,
      );
      await _localRepo?.savePayment(payment);
      _requestId = null;
      _fingerprint = null;
      state = const PaymentState();
    } on RemoteLoanException catch (e) {
      if (e.isRetryable && _localRepo != null) {
        final offlinePayment = _offlinePayment(
          loanId: loanId,
          amount: amount,
          effectiveDate: effectiveDate,
          note: note,
        );
        await _localRepo.savePayment(offlinePayment);
        await _syncService?.enqueue(
          endpoint: ApiEndpoints.loanPayments(loanId),
          method: 'POST',
          payload: <String, dynamic>{
            'requestId': _requestId,
            'amount': amount,
            'effectiveDate': effectiveDate,
            if (note.trim().isNotEmpty) 'note': note.trim(),
          },
        );
        _requestId = null;
        _fingerprint = null;
        state = const PaymentState();
        return;
      }
      state = PaymentState(preview: state.preview, error: e.message);
    }
  }

  Future<void> reversePayment({
    required String loanId,
    required String paymentId,
    required String effectiveDate,
    required String reason,
  }) async {
    final fingerprint = '$paymentId|$effectiveDate|$reason';
    if (_reversalFingerprint != fingerprint) {
      _reversalFingerprint = fingerprint;
      _reversalRequestId = const Uuid().v4();
    }
    state = PaymentState(working: true);
    try {
      final payment = await _paymentRepository.reverse(
        loanId: loanId,
        paymentId: paymentId,
        requestId: _reversalRequestId!,
        effectiveDate: effectiveDate,
        reason: reason,
      );
      await _localRepo?.savePayment(payment);
      _reversalRequestId = null;
      _reversalFingerprint = null;
      state = const PaymentState();
    } on RemoteLoanException catch (e) {
      if (e.isRetryable && _localRepo != null) {
        final offlinePayment = _offlineReversal(
          loanId: loanId,
          paymentId: paymentId,
          effectiveDate: effectiveDate,
          reason: reason,
        );
        await _localRepo.savePayment(offlinePayment);
        await _syncService?.enqueue(
          endpoint: '${ApiEndpoints.loanPayments(loanId)}/$paymentId/reversal',
          method: 'POST',
          payload: <String, dynamic>{
            'requestId': _reversalRequestId,
            'effectiveDate': effectiveDate,
            'reason': reason.trim(),
          },
        );
        _reversalRequestId = null;
        _reversalFingerprint = null;
        state = const PaymentState();
        return;
      }
      state = PaymentState(error: e.message);
    }
  }

  LoanPayment _offlinePayment({
    required String loanId,
    required String amount,
    required String effectiveDate,
    required String note,
  }) => LoanPayment(
    id: _requestId ?? '',
    requestId: _requestId ?? '',
    loanId: loanId,
    installmentId: null,
    entryType: 'Payment',
    reversalOfPaymentId: null,
    amount: amount,
    effectiveDate: effectiveDate,
    note: note.trim().isEmpty ? null : note.trim(),
    createdAt: DateTime.now().toUtc().toIso8601String(),
    allocation: const PaymentAllocation(
      appliedInterest: '0.00',
      appliedPrincipal: '0.00',
      unappliedCredit: '0.00',
      interestAfter: '0.00',
      principalAfter: '0.00',
      overdueDays: 0,
    ),
  );

  LoanPayment _offlineReversal({
    required String loanId,
    required String paymentId,
    required String effectiveDate,
    required String reason,
  }) => LoanPayment(
    id: _reversalRequestId ?? '',
    requestId: _reversalRequestId ?? '',
    loanId: loanId,
    installmentId: null,
    entryType: 'Reversal',
    reversalOfPaymentId: paymentId,
    amount: '0.00',
    effectiveDate: effectiveDate,
    note: reason.trim(),
    createdAt: DateTime.now().toUtc().toIso8601String(),
    allocation: const PaymentAllocation(
      appliedInterest: '0.00',
      appliedPrincipal: '0.00',
      unappliedCredit: '0.00',
      interestAfter: '0.00',
      principalAfter: '0.00',
      overdueDays: 0,
    ),
  );
}

final paymentNotifierProvider =
    StateNotifierProvider.autoDispose<PaymentNotifier, PaymentState>((ref) {
      return PaymentNotifier(
        ref.watch(remotePaymentRepositoryProvider),
        localRepo: ref.watch(localLoanRepositoryProvider),
        syncService: ref.watch(offlineSyncServiceProvider),
      );
    });
