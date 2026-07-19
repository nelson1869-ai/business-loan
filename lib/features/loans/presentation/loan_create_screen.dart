import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/loan_create_request.dart';
import '../data/repositories/remote_loan_repository.dart';
import 'providers/loans_provider.dart';

/// Collects lender-approved terms while leaving calculations to FastAPI.
class LoanCreateScreen extends ConsumerStatefulWidget {
  const LoanCreateScreen({super.key, required this.borrowerId});

  final String borrowerId;

  @override
  ConsumerState<LoanCreateScreen> createState() => _LoanCreateScreenState();
}

class _LoanCreateScreenState extends ConsumerState<LoanCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _principalController = TextEditingController();
  final _rateController = TextEditingController(text: '10');
  final _termController = TextEditingController(text: '1');
  int _paymentsPerMonth = 1;
  DateTime _startDate = DateTime.now();
  late DateTime _firstDueDate = DateTime(
    _startDate.year,
    _startDate.month + 1,
    _startDate.day,
  );
  bool _isSubmitting = false;

  @override
  void dispose() {
    _principalController.dispose();
    _rateController.dispose();
    _termController.dispose();
    super.dispose();
  }

  String? _validatePrincipal(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text)) {
      return 'Enter a positive amount with up to 2 decimal places';
    }
    if (RegExp(r'^0+(?:\.0{1,2})?$').hasMatch(text)) {
      return 'Principal must be greater than zero';
    }
    return null;
  }

  String? _validateRate(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d+(?:\.\d{1,6})?$').hasMatch(text)) {
      return 'Enter a percentage with up to 6 decimal places';
    }
    return null;
  }

  String? _validateTerm(String? value) {
    final term = int.tryParse(value?.trim() ?? '');
    if (term == null || term < 1 || term > 600) {
      return 'Enter a term from 1 to 600 months';
    }
    return null;
  }

  Future<void> _pickDate({required bool startDate}) async {
    final current = startDate ? _startDate : _firstDueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (startDate) {
        _startDate = picked;
        if (!_firstDueDate.isAfter(picked)) {
          _firstDueDate = DateTime(picked.year, picked.month + 1, picked.day);
        }
      } else {
        _firstDueDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_firstDueDate.isAfter(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('First due date must be after start date'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final loan = await ref
          .read(remoteLoanRepositoryProvider)
          .createLoan(
            LoanCreateRequest(
              borrowerId: widget.borrowerId,
              originalPrincipal: _principalController.text.trim(),
              monthlyRate: percentageToDecimalRate(_rateController.text.trim()),
              termMonths: int.parse(_termController.text.trim()),
              paymentsPerMonth: _paymentsPerMonth,
              startDate: formatDateOnly(_startDate),
              firstDueDate: formatDateOnly(_firstDueDate),
            ),
          );
      ref.invalidate(borrowerLoansProvider(widget.borrowerId));
      if (!mounted) return;
      context.pushReplacement('/loans/${loan.id}', extra: loan);
    } on RemoteLoanException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Loan')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextFormField(
              controller: _principalController,
              decoration: const InputDecoration(
                labelText: 'Principal Amount',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: _validatePrincipal,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rateController,
              decoration: const InputDecoration(
                labelText: 'Monthly Interest Rate (%)',
                helperText: 'Example: enter 10 for 10% per month',
                prefixIcon: Icon(Icons.percent),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: _validateRate,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _termController,
              decoration: const InputDecoration(
                labelText: 'Term (months)',
                prefixIcon: Icon(Icons.calendar_month_outlined),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: _validateTerm,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _paymentsPerMonth,
              decoration: const InputDecoration(
                labelText: 'Payment Frequency',
                prefixIcon: Icon(Icons.event_repeat),
              ),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem(value: 1, child: Text('Once a month')),
                DropdownMenuItem(value: 2, child: Text('Twice a month')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _paymentsPerMonth = value);
              },
            ),
            const SizedBox(height: 16),
            _DateField(
              label: 'Start Date',
              value: _startDate,
              onTap: () => _pickDate(startDate: true),
            ),
            const SizedBox(height: 16),
            _DateField(
              label: 'First Due Date',
              value: _firstDueDate,
              onTap: () => _pickDate(startDate: false),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSubmitting ? 'Creating…' : 'Create Loan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
        ),
        child: Text(formatDateOnly(value)),
      ),
    );
  }
}

/// Converts a human percentage to an exact fractional decimal without doubles.
String percentageToDecimalRate(String percentage) {
  final parts = percentage.split('.');
  final fractionalDigits = parts.length == 2 ? parts[1].length : 0;
  final digits = percentage.replaceAll('.', '');
  final numerator = BigInt.parse(digits);
  final scale = fractionalDigits + 2;
  final padded = numerator.toString().padLeft(scale + 1, '0');
  final splitAt = padded.length - scale;
  final whole = padded.substring(0, splitAt);
  var fraction = padded.substring(splitAt).replaceFirst(RegExp(r'0+$'), '');
  if (fraction.isEmpty) fraction = '0';
  return '$whole.$fraction';
}

/// Formats a local calendar selection as the backend's date-only value.
String formatDateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
