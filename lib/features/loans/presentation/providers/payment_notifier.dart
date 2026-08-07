import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/offline_sync_service.dart';
import '../../data/repositories/local_loan_repository.dart';
import '../../data/repositories/remote_payment_repository.dart';
import '../../domain/models/payment.dart';

class PaymentState {
  final PaymentPreview? preview;
  final bool working;
  final String? error;

  const PaymentState({this.preview, this.working = false, this.error});
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  PaymentNotifier(this.ref) : super(const PaymentState());

  final Ref ref;

  void resetPreview() {
    state = const PaymentState(preview: null);
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
    state = const PaymentState(working: true);
    try {
      final preview = await ref
          .read(remotePaymentRepositoryProvider)
          .preview(
            loanId: loanId,
            amount: amount,
            effectiveDate: effectiveDate,
          );
      state = PaymentState(preview: preview);
    } on Object catch (error) {
      state = PaymentState(error: error.toString());
    }
  }

  Future<void> confirm({
    required String loanId,
    required String amount,
    required String effectiveDate,
    required String method,
    required String deviceId,
    String? collectionSessionId,
    String? receiptNumber,
    required String note,
  }) async {
    final preview = state.preview;
    if (preview == null) return;
    final fingerprint =
        '$amount|$effectiveDate|$method|$collectionSessionId|$receiptNumber|$note';
    if (_fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      _requestId = const Uuid().v4();
    }
    state = PaymentState(preview: state.preview, working: true);
    if (method == 'cash') {
      try {
        await ref
            .read(remotePaymentRepositoryProvider)
            .confirm(
              loanId: loanId,
              requestId: _requestId!,
              amount: amount,
              effectiveDate: effectiveDate,
              method: method,
              deviceId: deviceId,
              collectionSessionId: collectionSessionId,
              receiptNumber: receiptNumber,
              note: note,
            );
        _requestId = null;
        _fingerprint = null;
        state = const PaymentState();
      } on Object catch (error) {
        state = PaymentState(preview: preview, error: error.toString());
      }
      return;
    }
    final localRepo = ref.read(localLoanRepositoryProvider);
    final syncService = ref.read(offlineSyncServiceProvider);
    final offlinePayment = _offlinePayment(
      loanId: loanId,
      amount: amount,
      effectiveDate: effectiveDate,
      note: note,
      preview: preview,
    );
    await localRepo.savePayment(offlinePayment, syncStatus: 'pending');
    await localRepo.applyPaymentPreview(preview);
    await syncService.enqueue(
      endpoint: ApiEndpoints.loanPayments(loanId),
      method: 'POST',
      payload: <String, dynamic>{
        'requestId': _requestId,
        'amount': amount,
        'effectiveDate': effectiveDate,
        'paymentMethod': method,
        'deviceId': deviceId,
        'collectionSessionId': ?collectionSessionId,
        if (receiptNumber != null && receiptNumber.trim().isNotEmpty)
          'receiptNumber': receiptNumber.trim(),
        if (note.trim().isNotEmpty) 'note': note.trim(),
      },
      entityType: 'repayment',
      entityLocalId: offlinePayment.id,
      operationType: 'create',
      dependencyIds: [loanId],
    );
    unawaited(syncService.drainQueue());
    _requestId = null;
    _fingerprint = null;
    state = const PaymentState();
  }

  Future<void> reversePayment({
    required String loanId,
    required String paymentId,
    required String effectiveDate,
    required String reason,
    String? approvalRequestId,
  }) async {
    final fingerprint = '$paymentId|$effectiveDate|$reason';
    if (_reversalFingerprint != fingerprint) {
      _reversalFingerprint = fingerprint;
      _reversalRequestId = const Uuid().v4();
    }
    state = const PaymentState(working: true);
    try {
      await ref
          .read(remotePaymentRepositoryProvider)
          .reverse(
            loanId: loanId,
            paymentId: paymentId,
            requestId: _reversalRequestId!,
            effectiveDate: effectiveDate,
            reason: reason,
            approvalRequestId: approvalRequestId,
          );
      _reversalRequestId = null;
      _reversalFingerprint = null;
      state = const PaymentState();
    } on Object catch (error) {
      state = PaymentState(error: error.toString());
    }
  }

  LoanPayment _offlinePayment({
    required String loanId,
    required String amount,
    required String effectiveDate,
    required String note,
    required PaymentPreview preview,
  }) => LoanPayment(
    id: _requestId ?? const Uuid().v4(),
    requestId: _requestId ?? const Uuid().v4(),
    loanId: loanId,
    installmentId: preview.installmentId,
    entryType: 'Payment',
    reversalOfPaymentId: null,
    amount: amount,
    effectiveDate: effectiveDate,
    note: note.trim().isEmpty ? null : note.trim(),
    createdAt: DateTime.now().toUtc().toIso8601String(),
    allocation: PaymentAllocation(
      appliedInterest: preview.appliedInterest,
      appliedPrincipal: preview.appliedPrincipal,
      unappliedCredit: preview.unappliedCredit,
      interestAfter: preview.interestAfter,
      principalAfter: preview.principalAfter,
      overdueDays: preview.overdueDays,
    ),
  );
}

final paymentNotifierProvider =
    StateNotifierProvider.autoDispose<PaymentNotifier, PaymentState>((ref) {
      return PaymentNotifier(ref);
    });
