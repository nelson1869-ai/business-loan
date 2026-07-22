import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../domain/models/payment.dart';
import 'providers/loans_provider.dart';
import 'providers/payment_notifier.dart';
import 'widgets/payment_form_card.dart';
import 'widgets/payment_preview_card.dart';
import 'widgets/payment_reversal_dialog.dart';
import 'widgets/payment_history_section.dart';

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
  DateTime _effectiveDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
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
    ref
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
    await ref
        .read(paymentNotifierProvider.notifier)
        .confirm(
          loanId: widget.loanId,
          amount: _amountController.text.trim(),
          effectiveDate: _date,
          note: _noteController.text,
        );
    if (!mounted) return;
    if (ref.read(paymentNotifierProvider).error != null) return;
    ref.invalidate(loanPaymentsProvider(widget.loanId));
    ref.invalidate(loanDetailProvider(widget.loanId));
    _amountController.clear();
    _noteController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded successfully')),
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
    await ref
        .read(paymentNotifierProvider.notifier)
        .reversePayment(
          loanId: widget.loanId,
          paymentId: payment.id,
          effectiveDate: formatDateOnly(result.$2),
          reason: result.$1,
        );
    if (!mounted) return;
    if (ref.read(paymentNotifierProvider).error != null) return;
    ref.invalidate(loanPaymentsProvider(widget.loanId));
    ref.invalidate(loanDetailProvider(widget.loanId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment reversed successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentNotifierProvider);
    final history = ref.watch(loanPaymentsProvider(widget.loanId));
    final loanAsync = ref.watch(loanDetailProvider(widget.loanId));
    final working = paymentState.working;
    final theme = Theme.of(context);

    String? installmentAmount;
    String? outstandingPrincipal;
    final loan = loanAsync.valueOrNull;
    if (loan != null) {
      outstandingPrincipal = loan.outstandingPrincipal;
      for (final inst in loan.installments) {
        final paid = double.tryParse(inst.paidAmount) ?? 0;
        final expected = double.tryParse(inst.expectedPayment) ?? 0;
        if (paid < expected) {
          installmentAmount = (expected - paid).toStringAsFixed(2);
          break;
        }
      }
      installmentAmount ??= loan.regularPaymentAmount;
    }

    ref.listen(paymentNotifierProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Loan Payments')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PaymentFormCard(
            formKey: _formKey,
            amountController: _amountController,
            noteController: _noteController,
            dateLabel: _date,
            working: working,
            theme: theme,
            installmentAmount: installmentAmount,
            outstandingPrincipal: outstandingPrincipal,
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
          const SizedBox(height: 24),
          Text('Payment History', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          history.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not load payments: $error'),
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
                    onReverse: _reversePayment,
                  ),
          ),
        ],
      ),
    );
  }
}
