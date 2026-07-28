import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/utils/loan_calculator.dart';
import '../../../core/utils/formatters.dart';
import '../domain/models/payment.dart';
import '../domain/models/loan.dart';
import 'providers/loans_provider.dart';
import 'providers/payment_notifier.dart';
import 'widgets/payment_borrower_card.dart';
import 'widgets/payment_form_card.dart';
import 'widgets/payment_history_section.dart';
import 'widgets/payment_preview_card.dart';
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
    final loan = ref.read(loanDetailProvider(widget.loanId)).valueOrNull;
    if (loan == null) return;
    final terms = _paymentTerms(loan);
    if (terms == null) return;
    ref
        .read(paymentNotifierProvider.notifier)
        .loadPreview(
          loanId: widget.loanId,
          amount: _amountController.text.trim(),
          effectiveDate: _date,
          outstandingPrincipal: loan.outstandingPrincipal,
          interestDue: terms.quote.interestDue,
          dueDate: terms.dueDate,
          daysEarly: terms.quote.daysEarly,
          overdueDays: terms.quote.overdueDays,
          scheduledPayment: terms.installmentAmount,
          periodicRate: terms.periodicRate,
          installmentId: terms.installmentId,
        );
  }

  _PaymentTerms? _paymentTerms(Loan loan) {
    final openInstallments = loan.installments
        .where((item) => item.status != 'Paid' && item.status != 'Cancelled')
        .toList()
      ..sort(
        (left, right) =>
            left.installmentNumber.compareTo(right.installmentNumber),
      );
    if (openInstallments.isEmpty) return null;

    final installment = openInstallments.first;
    final dueDate = DateTime.tryParse(installment.dueDate);
    final installmentIndex = loan.installments.indexOf(installment);
    final periodStart = installmentIndex > 0
        ? DateTime.tryParse(loan.installments[installmentIndex - 1].dueDate)
        : DateTime.tryParse(loan.startDate);
    final monthlyRate = double.tryParse(loan.monthlyRate);
    if (dueDate == null ||
        periodStart == null ||
        monthlyRate == null ||
        loan.paymentsPerMonth <= 0) {
      return null;
    }

    var remainingCredit = double.tryParse(loan.unappliedCredit) ?? 0;
    final expected = double.tryParse(installment.expectedPayment) ?? 0;
    final paid = double.tryParse(installment.paidAmount) ?? 0;
    final installmentAmount = (expected - paid - remainingCredit).clamp(
      0.0,
      double.infinity,
    );
    final periodicRate = monthlyRate / loan.paymentsPerMonth;
    try {
      final quote = LoanCalculator.quotePayoff(
        outstandingPrincipal: loan.outstandingPrincipal,
        periodicRate: periodicRate,
        periodStartDate: periodStart,
        dueDate: dueDate,
        effectiveDate: _effectiveDate,
      );
      return _PaymentTerms(
        quote: quote,
        installmentAmount: installmentAmount.toStringAsFixed(2),
        dueDate: installment.dueDate,
        periodicRate: periodicRate,
        installmentId: installment.id,
      );
    } on LoanCalculationException {
      return null;
    }
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

    final loan = loanAsync.valueOrNull;
    final terms = loan == null ? null : _paymentTerms(loan);
    final installmentAmount = terms?.installmentAmount;
    final payoffAmount = terms?.quote.payoffAmount;

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
              PaymentSummaryCards(
                loan: loan,
                installmentAmount: installmentAmount,
              ),
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
            else ...[
              PaymentFormCard(
                formKey: _formKey,
                amountController: _amountController,
                noteController: _noteController,
                dateLabel: _date,
                working: working,
                theme: theme,
                installmentAmount: installmentAmount,
                payoffAmount: payoffAmount,
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
            ],
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
                      onReverse: _reversePayment,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTerms {
  const _PaymentTerms({
    required this.quote,
    required this.installmentAmount,
    required this.dueDate,
    required this.periodicRate,
    required this.installmentId,
  });

  final LoanPayoffQuote quote;
  final String installmentAmount;
  final String dueDate;
  final double periodicRate;
  final String installmentId;
}
