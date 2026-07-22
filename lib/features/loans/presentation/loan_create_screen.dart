import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../borrowers/domain/borrower_model.dart';
import 'providers/loan_create_notifier.dart';
import 'providers/loans_provider.dart';
import 'widgets/loan_date_field.dart';

class LoanCreateScreen extends ConsumerStatefulWidget {
  const LoanCreateScreen({super.key, required this.borrowerId, this.borrower});

  final String borrowerId;
  final Borrower? borrower;

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

    final loan = await ref
        .read(loanCreateNotifierProvider.notifier)
        .submit(
          borrowerId: widget.borrowerId,
          borrower: widget.borrower,
          principal: _principalController.text.trim(),
          rate: _rateController.text.trim(),
          termMonths: int.parse(_termController.text.trim()),
          paymentsPerMonth: _paymentsPerMonth,
          startDate: _startDate,
          firstDueDate: _firstDueDate,
        );

    if (!mounted) return;
    if (loan != null) {
      context.pushReplacement('/loans/${loan.id}', extra: loan);
    } else {
      final error = ref.read(loanCreateNotifierProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(loanCreateNotifierProvider).isSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Loan')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Consumer(
              builder: (context, ref, child) {
                final loansAsync = ref.watch(
                  borrowerLoansProvider(widget.borrowerId),
                );
                final loans = loansAsync.asData?.value ?? const [];
                final activeLoans = loans
                    .where((l) => l.status.toUpperCase() == 'ACTIVE')
                    .toList();
                if (activeLoans.isEmpty) return const SizedBox.shrink();

                final totalBalance = activeLoans.fold(
                  0.0,
                  (sum, l) =>
                      sum + (double.tryParse(l.outstandingPrincipal) ?? 0.0),
                );

                return Card(
                  color: Colors.amber.shade900.withValues(alpha: 0.15),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: Colors.amber.shade400,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Borrower Exposure Risk',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade300,
                                ),
                              ),
                              Text(
                                '${activeLoans.length} Active Loan(s) · \$${totalBalance.toStringAsFixed(2)} Total Outstanding',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            TextFormField(
              controller: _principalController,
              decoration: const InputDecoration(
                labelText: 'Principal Amount',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: _validatePrincipal,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: ['500', '1000', '2000', '5000'].map((preset) {
                return ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text('\$$preset'),
                  onPressed: isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _principalController.text = preset;
                          });
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
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
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: _validateRate,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _termController,
              decoration: const InputDecoration(
                labelText: 'Term (months)',
                prefixIcon: Icon(Icons.calendar_month_outlined),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _validateTerm,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _paymentsPerMonth,
              decoration: const InputDecoration(
                labelText: 'Payment Frequency',
                prefixIcon: Icon(Icons.event_repeat),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Once a month')),
                DropdownMenuItem(value: 2, child: Text('Twice a month')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _paymentsPerMonth = v);
              },
            ),
            const SizedBox(height: 8),
            LoanDateField(
              label: 'Start Date',
              value: _startDate,
              onTap: () => _pickDate(startDate: true),
            ),
            const SizedBox(height: 8),
            LoanDateField(
              label: 'First Due Date',
              value: _firstDueDate,
              onTap: () => _pickDate(startDate: false),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isSubmitting ? null : _submit,
              icon: isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(isSubmitting ? 'Creating\u2026' : 'Create Loan'),
            ),
          ],
        ),
      ),
    );
  }
}
