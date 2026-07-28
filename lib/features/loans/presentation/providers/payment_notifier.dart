import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/offline_sync_service.dart';
import '../../../../core/utils/loan_calculator.dart';
import '../../data/repositories/local_loan_repository.dart';
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
    required String outstandingPrincipal,
    required String interestDue,
    required String dueDate,
    required int daysEarly,
    required int overdueDays,
    required String scheduledPayment,
    required double periodicRate,
    required String installmentId,
  }) async {
    state = const PaymentState(working: true);
    final alloc = LoanCalculator.allocatePayment(
      paymentAmount: amount,
      interestDue: interestDue,
      outstandingPrincipal: outstandingPrincipal,
    );
    final amountCents = LoanCalculator.parseCents(amount, 'paymentAmount');
    final scheduledCents = LoanCalculator.parseCents(
      scheduledPayment,
      'scheduledPayment',
    );
    state = PaymentState(
      preview: PaymentPreview(
        loanId: loanId,
        installmentId: installmentId,
        paymentAmount: amount,
        effectiveDate: effectiveDate,
        dueDate: dueDate,
        daysEarly: daysEarly,
        overdueDays: overdueDays,
        accruedInterest: interestDue,
        totalInterestBefore: interestDue,
        principalBefore: outstandingPrincipal,
        appliedInterest: alloc.appliedToInterest,
        appliedPrincipal: alloc.appliedToPrincipal,
        unappliedCredit: alloc.unappliedCredit,
        interestAfter: alloc.remainingInterest,
        principalAfter: alloc.remainingPrincipal,
        amountAboveScheduled: LoanCalculator.formatCents(
          (amountCents - scheduledCents).clamp(0, amountCents).toInt(),
        ),
        nextPeriodInterest: LoanCalculator.calculatePeriodInterest(
          alloc.remainingPrincipal,
          periodicRate,
        ),
        isPayoff:
            alloc.remainingInterest == '0.00' &&
            alloc.remainingPrincipal == '0.00',
      ),
    );
  }

  Future<void> confirm({
    required String loanId,
    required String amount,
    required String effectiveDate,
    required String note,
  }) async {
    final preview = state.preview;
    if (preview == null) return;
    final fingerprint = '$amount|$effectiveDate|$note';
    if (_fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      _requestId = const Uuid().v4();
    }
    state = PaymentState(preview: state.preview, working: true);
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
  }) async {
    final fingerprint = '$paymentId|$effectiveDate|$reason';
    if (_reversalFingerprint != fingerprint) {
      _reversalFingerprint = fingerprint;
      _reversalRequestId = const Uuid().v4();
    }
    state = const PaymentState(working: true);
    final localRepo = ref.read(localLoanRepositoryProvider);
    final syncService = ref.read(offlineSyncServiceProvider);
    final offlinePayment = _offlineReversal(
      loanId: loanId,
      paymentId: paymentId,
      effectiveDate: effectiveDate,
      reason: reason,
    );
    await localRepo.savePayment(offlinePayment, syncStatus: 'pending');
    await syncService.enqueue(
      endpoint: '${ApiEndpoints.loanPayments(loanId)}/$paymentId/reversal',
      method: 'POST',
      payload: <String, dynamic>{
        'requestId': _reversalRequestId,
        'effectiveDate': effectiveDate,
        'reason': reason.trim(),
      },
      entityType: 'repayment',
      entityLocalId: offlinePayment.id,
      operationType: 'create',
      dependencyIds: [loanId, paymentId],
    );
    unawaited(syncService.drainQueue());
    _reversalRequestId = null;
    _reversalFingerprint = null;
    state = const PaymentState();
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

  LoanPayment _offlineReversal({
    required String loanId,
    required String paymentId,
    required String effectiveDate,
    required String reason,
  }) => LoanPayment(
    id: _reversalRequestId ?? const Uuid().v4(),
    requestId: _reversalRequestId ?? const Uuid().v4(),
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
      return PaymentNotifier(ref);
    });
