import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/security/device_identifier.dart';
import '../../../core/security/officer_session.dart';
import '../../approvals/data/approval_repository.dart';
import '../../collection_sessions/data/collection_session_repository.dart';
import '../../collection_sessions/presentation/collection_session_provider.dart';
import '../domain/models/payment.dart';
import '../../borrower_communication/presentation/borrower_communication_provider.dart';
import '../../borrower_communication/presentation/send_to_borrower_sheet.dart';
import '../../borrower_communication/data/borrower_due_reminder_scheduler.dart';
import '../domain/models/loan.dart';
import 'providers/loans_provider.dart';
import 'providers/payment_notifier.dart';
import 'widgets/payment_borrower_card.dart';
import 'widgets/payment_form_card.dart';
import 'widgets/payment_history_section.dart';
import 'widgets/payment_preview_card.dart';
import 'payment_success_dialog.dart';
import 'widgets/payment_reversal_dialog.dart';
import 'widgets/payment_summary_cards.dart';

/// Redesigned Material 3 Payment Collection Screen.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.loanId});

  final String loanId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _receiptController = TextEditingController();
  DateTime _effectiveDate = DateTime.now();
  String _paymentMethod = 'cash';
  String? _collectionSessionId;

  @override
  void initState() {
    super.initState();
    _autoGenerateReceiptNumber();
  }

  void _autoGenerateReceiptNumber() {
    final now = DateTime.now();
    final yyyymmdd =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomDigits = (1000 + Random().nextInt(9000)).toString();
    setState(() {
      _receiptController.text = 'OR-$yyyymmdd-$randomDigits';
    });
  }

  void _autoGenerateNote() {
    final amountVal = double.tryParse(_amountController.text.trim());
    final loan = ref.read(loanDetailProvider(widget.loanId)).valueOrNull;

    final methodStr = switch (_paymentMethod) {
      'cash' => 'Cash',
      'bank' => 'Bank transfer',
      'mobile_money' => 'Mobile money',
      _ => 'Other',
    };

    String noteText = 'Payment collected via $methodStr.';

    if (amountVal != null && amountVal > 0 && loan != null) {
      final regular = double.tryParse(loan.regularPaymentAmount) ?? 0.0;
      final payoff = double.tryParse(loan.outstandingPrincipal) ?? 0.0;

      if (payoff > 0 && (amountVal - payoff).abs() < 0.01) {
        noteText =
            'Full loan payoff of ${formatCurrency(amountVal.toString())} collected via $methodStr.';
      } else if (regular > 0 && (amountVal - regular).abs() < 0.01) {
        noteText =
            'Regular scheduled installment of ${formatCurrency(amountVal.toString())} collected via $methodStr.';
      } else if (regular > 0 && amountVal < regular) {
        noteText =
            'Partial payment of ${formatCurrency(amountVal.toString())} received via $methodStr.';
      } else if (regular > 0 && amountVal > regular) {
        noteText =
            'Advance/Overpayment of ${formatCurrency(amountVal.toString())} received via $methodStr.';
      } else {
        noteText =
            'Payment of ${formatCurrency(amountVal.toString())} received via $methodStr.';
      }
    }

    setState(() {
      _noteController.text = noteText;
    });
    ref.read(paymentNotifierProvider.notifier).resetPreview();
  }

  Future<void> _autoOpenCollectionSession() async {
    final session = ref.read(officerSessionProvider).valueOrNull;
    if (session == null) return;
    try {
      final newSession = await ref
          .read(collectionSessionRepositoryProvider)
          .open(collectorUserId: session.userId, openingCash: '0.00');
      ref.invalidate(collectionSessionsProvider);
      if (mounted) {
        setState(() {
          _collectionSessionId = newSession.id;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collection session opened successfully!'),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorMapper.message(error))),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _receiptController.dispose();
    super.dispose();
  }

  String get _date => formatDateOnly(_effectiveDate);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (picked != null && mounted) {
      setState(() => _effectiveDate = picked);
      ref.read(paymentNotifierProvider.notifier).resetPreview();
    }
  }

  Future<void> _loadPreview() async {
    if (!_formKey.currentState!.validate()) return;
    final loan = ref.read(loanDetailProvider(widget.loanId)).valueOrNull;
    if (loan == null) return;
    await ref
        .read(paymentNotifierProvider.notifier)
        .loadPreview(
          loanId: widget.loanId,
          amount: _amountController.text.trim(),
          effectiveDate: _date,
        );
  }

  Future<void> _confirm() async {
    final preview = ref.read(paymentNotifierProvider).preview;
    if (preview == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm payment?'),
        content: Text(
          'Record ${formatCurrency(preview.paymentAmount)}?\n\n'
          'Interest: ${formatCurrency(preview.appliedInterest)}\n'
          'Principal: ${formatCurrency(preview.appliedPrincipal)}\n'
          'Balance after: ${formatCurrency(preview.principalAfter)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final deviceId = await ref.read(deviceIdentifierProvider.future);
    if (!mounted) return;

    final collectionSessions =
        ref.read(collectionSessionsProvider).valueOrNull ?? const [];
    final session = ref.read(officerSessionProvider).valueOrNull;
    final activeSessions = collectionSessions.where(
      (item) =>
          item.collectorUserId == session?.userId &&
          (item.status == 'open' || item.status == 'collecting'),
    ).toList();
    var effectiveSessionId =
        _collectionSessionId ?? (activeSessions.isNotEmpty ? activeSessions.first.id : null);

    if (_paymentMethod == 'cash' &&
        (effectiveSessionId == null || effectiveSessionId.isEmpty)) {
      await _autoOpenCollectionSession();
      effectiveSessionId = _collectionSessionId;
      if (effectiveSessionId == null || effectiveSessionId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'An active collection session is required to record cash payments.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    await ref
        .read(paymentNotifierProvider.notifier)
        .confirm(
          loanId: widget.loanId,
          amount: _amountController.text.trim(),
          effectiveDate: _date,
          method: _paymentMethod,
          deviceId: deviceId,
          collectionSessionId: effectiveSessionId,
          receiptNumber: _receiptController.text,
          note: _noteController.text,
        );
    if (!mounted) return;
    if (ref.read(paymentNotifierProvider).error != null) return;
    ref.invalidate(loanPaymentsProvider(widget.loanId));
    ref.invalidate(loanDetailProvider(widget.loanId));
    unawaited(
      ref
          .read(borrowerDueReminderSchedulerProvider)
          .refresh()
          .catchError((_) {}),
    );
    final savedReceiptNum = _receiptController.text;
    final savedAmount = preview.paymentAmount;
    final savedRemaining = preview.principalAfter;

    _amountController.clear();
    _noteController.clear();
    _autoGenerateReceiptNumber();
    if (mounted) {
      showDialog<void>(
        context: context,
        builder: (ctx) => PaymentSuccessDialog(
          receiptNumber: savedReceiptNum,
          amountReceived: formatCurrency(savedAmount),
          remainingBalance: formatCurrency(savedRemaining),
          onViewReceipt: () {
            // View receipt / navigation if desired
          },
        ),
      );
    }
  }

  Future<void> _reversePayment(LoanPayment payment) async {
    final paymentDate = DateTime.parse(payment.effectiveDate);
    final result = await showDialog<(String, DateTime)>(
      context: context,
      builder: (_) => PaymentReversalDialog(paymentDate: paymentDate),
    );
    if (result == null || !mounted) return;
    final approvals = await ref.read(approvalRepositoryProvider).list();
    final session = await ref.read(officerSessionProvider.future);
    if (!mounted || session == null) return;
    final approved = approvals.where(
      (request) =>
          request.action == 'payment.reverse' &&
          request.entityType == 'payment' &&
          request.entityId == payment.id &&
          request.makerUserId == session.userId &&
          request.status == 'approved',
    );
    if (approved.isEmpty) {
      await ref
          .read(approvalRepositoryProvider)
          .create(
            action: 'payment.reverse',
            entityType: 'payment',
            entityId: payment.id,
            reason: result.$1,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reversal approval requested. A different authorized user must approve it before reversal.',
          ),
        ),
      );
      return;
    }
    await ref
        .read(paymentNotifierProvider.notifier)
        .reversePayment(
          loanId: widget.loanId,
          paymentId: payment.id,
          effectiveDate: formatDateOnly(result.$2),
          reason: result.$1,
          approvalRequestId: approved.last.id,
        );
    if (!mounted) return;
    if (ref.read(paymentNotifierProvider).error != null) return;
    ref.invalidate(loanPaymentsProvider(widget.loanId));
    ref.invalidate(loanDetailProvider(widget.loanId));
    unawaited(
      ref
          .read(borrowerDueReminderSchedulerProvider)
          .refresh()
          .catchError((_) {}),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment reversed successfully')),
      );
    }
  }

  Future<void> _sendReceipt(Loan loan, LoanPayment payment) {
    return SendToBorrowerSheet.show(
      context,
      BorrowerCommunicationRequest(
        borrowerId: loan.borrowerId,
        loan: loan,
        payment: payment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentNotifierProvider);
    final history = ref.watch(loanPaymentsProvider(widget.loanId));
    final loanAsync = ref.watch(loanDetailProvider(widget.loanId));
    final working = paymentState.working;
    final theme = Theme.of(context);
    final session = ref.watch(officerSessionProvider).valueOrNull;
    final canCollect = session?.can('payment.collect') ?? false;
    final canRequestReversal = session?.can('payment.collect') ?? false;
    final collectionSessions = ref.watch(collectionSessionsProvider);

    final loan = loanAsync.valueOrNull;
    final activeSessions =
        collectionSessions.valueOrNull
            ?.where(
              (item) =>
                  item.collectorUserId == session?.userId &&
                  (item.status == 'open' || item.status == 'collecting'),
            )
            .toList(growable: false) ??
        const [];
    final sessionOptions = {
      for (final item in activeSessions)
        item.id: 'Opened ${formatDateOnly(item.createdAt)}',
    };

    final selectedSessionId =
        (_collectionSessionId != null &&
                sessionOptions.containsKey(_collectionSessionId))
            ? _collectionSessionId
            : (activeSessions.isNotEmpty ? activeSessions.first.id : null);

    ref.listen(paymentNotifierProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/loans');
            }
          },
        ),
        title: const Text('Payment Collection'),
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (loan != null) ...[
              PaymentBorrowerCard(loan: loan),
              const SizedBox(height: 14),
              PaymentSummaryCards(loan: loan),
              const SizedBox(height: 16),
            ],
            if (loan?.status == 'Paid')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Loan paid in full. No further payment is due.',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (canCollect) ...[
              PaymentFormCard(
                formKey: _formKey,
                amountController: _amountController,
                installmentAmount: loan?.regularPaymentAmount,
                payoffAmount: loan?.outstandingPrincipal,
                noteController: _noteController,
                dateLabel: _date,
                working: working,
                theme: theme,
                method: _paymentMethod,
                onMethodChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _paymentMethod = value;
                    if (value != 'cash') _collectionSessionId = null;
                  });
                  ref.read(paymentNotifierProvider.notifier).resetPreview();
                },
                receiptController: _receiptController,
                onAutoGenerateReceipt: _autoGenerateReceiptNumber,
                onAutoGenerateNote: _autoGenerateNote,
                sessionOptions: sessionOptions,
                collectionSessionId: selectedSessionId,
                onSessionChanged: (value) {
                  setState(() => _collectionSessionId = value);
                  ref.read(paymentNotifierProvider.notifier).resetPreview();
                },
                onAutoOpenSession: _autoOpenCollectionSession,
                onPickDate: _pickDate,
                onPreview: _loadPreview,
                onFieldChange: () =>
                    ref.read(paymentNotifierProvider.notifier).resetPreview(),
              ),
              if (paymentState.preview case final preview?) ...[
                const SizedBox(height: 12),
                PaymentPreviewCard(
                  preview: preview,
                  working: working,
                  onConfirm: _confirm,
                ),
              ],
            ] else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'You do not have permission to collect payments.',
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text('Payment History', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(ApiErrorMapper.message(error)),
                ),
              ),
              data: (payments) => payments.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No payments recorded yet.'),
                      ),
                    )
                  : PaymentHistorySection(
                      payments: payments,
                      working: working,
                      onReverse: canRequestReversal ? _reversePayment : null,
                      onSendToBorrower: loan == null
                          ? null
                          : (payment) => _sendReceipt(loan, payment),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
