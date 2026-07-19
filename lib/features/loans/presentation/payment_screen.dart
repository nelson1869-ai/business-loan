import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/repositories/remote_loan_repository.dart';
import '../data/repositories/remote_payment_repository.dart';
import '../domain/models/payment.dart';
import 'providers/loans_provider.dart';

/// Previews, confirms, and reviews payments without calculating money locally.
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
  PaymentPreview? _preview;
  bool _working = false;
  String? _requestId;
  String? _fingerprint;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _date =>
      '${_effectiveDate.year.toString().padLeft(4, '0')}-'
      '${_effectiveDate.month.toString().padLeft(2, '0')}-'
      '${_effectiveDate.day.toString().padLeft(2, '0')}';

  String? _validateAmount(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text) ||
        RegExp(r'^0+(?:\.0{1,2})?$').hasMatch(text)) {
      return 'Enter an amount greater than zero with up to 2 decimals';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (picked != null && mounted) {
      setState(() {
        _effectiveDate = picked;
        _preview = null;
      });
    }
  }

  Future<void> _loadPreview() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _working = true;
      _preview = null;
    });
    try {
      final preview = await ref
          .read(remotePaymentRepositoryProvider)
          .preview(
            loanId: widget.loanId,
            amount: _amountController.text.trim(),
            effectiveDate: _date,
          );
      if (mounted) setState(() => _preview = preview);
    } on RemoteLoanException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _confirm() async {
    final preview = _preview;
    if (preview == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm payment?'),
        content: Text(
          'Record ${preview.paymentAmount}?\n\n'
          'Interest: ${preview.appliedInterest}\n'
          'Principal: ${preview.appliedPrincipal}\n'
          'Balance after: ${preview.principalAfter}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    final fingerprint =
        '${_amountController.text.trim()}|$_date|${_noteController.text.trim()}';
    if (_fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      _requestId = const Uuid().v4();
    }
    setState(() => _working = true);
    try {
      await ref
          .read(remotePaymentRepositoryProvider)
          .confirm(
            loanId: widget.loanId,
            requestId: _requestId!,
            amount: _amountController.text.trim(),
            effectiveDate: _date,
            note: _noteController.text,
          );
      ref.invalidate(loanPaymentsProvider(widget.loanId));
      ref.invalidate(loanDetailProvider(widget.loanId));
      if (!mounted) return;
      setState(() {
        _preview = null;
        _requestId = null;
        _fingerprint = null;
        _amountController.clear();
        _noteController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded successfully')),
      );
    } on RemoteLoanException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(loanPaymentsProvider(widget.loanId));
    return Scaffold(
      appBar: AppBar(title: const Text('Loan Payments')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Form(
            key: _formKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Record a payment',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      enabled: !_working,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: _validateAmount,
                      onChanged: (_) => setState(() => _preview = null),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event),
                      title: const Text('Effective date'),
                      subtitle: Text(_date),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: _working ? null : _pickDate,
                    ),
                    TextField(
                      controller: _noteController,
                      enabled: !_working,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                      ),
                      onChanged: (_) => setState(() => _preview = null),
                    ),
                    FilledButton.icon(
                      onPressed: _working ? null : _loadPreview,
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('Preview Payment'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_preview case final preview?) ...<Widget>[
            const SizedBox(height: 12),
            _PreviewCard(
              preview: preview,
              working: _working,
              onConfirm: _confirm,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Payment History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
                : Column(
                    children: payments
                        .map((payment) => _PaymentTile(payment: payment))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.preview,
    required this.working,
    required this.onConfirm,
  });
  final PaymentPreview preview;
  final bool working;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Backend preview',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          _row('Payment', preview.paymentAmount),
          _row('Interest', preview.appliedInterest),
          _row('Principal', preview.appliedPrincipal),
          _row('Extra above schedule', preview.amountAboveScheduled),
          _row('Interest remaining', preview.interestAfter),
          _row('Principal remaining', preview.principalAfter),
          _row('Next-period interest', preview.nextPeriodInterest),
          if (preview.overdueDays > 0)
            _row('Days late', '${preview.overdueDays}'),
          if (preview.daysEarly > 0) _row('Days early', '${preview.daysEarly}'),
          if (preview.unappliedCredit != '0.00')
            _row('Unapplied credit', preview.unappliedCredit),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: working ? null : onConfirm,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              preview.isPayoff ? 'Confirm Payoff' : 'Confirm Payment',
            ),
          ),
        ],
      ),
    ),
  );
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});
  final LoanPayment payment;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: Text(payment.amount),
      subtitle: Text(payment.effectiveDate),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: <Widget>[
        _row('Interest', payment.allocation.appliedInterest),
        _row('Principal', payment.allocation.appliedPrincipal),
        _row('Balance after', payment.allocation.principalAfter),
        if (payment.note case final note?)
          Align(alignment: Alignment.centerLeft, child: Text('Note: $note')),
      ],
    ),
  );
}

Widget _row(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(
    children: <Widget>[
      Expanded(child: Text(label)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  ),
);
