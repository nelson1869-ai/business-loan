import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../borrowers/domain/borrower_model.dart';
import '../../borrowers/providers/borrower_recommendation_provider.dart';
import '../../borrowers/widgets/borrower_recommendation_card.dart';
import 'providers/loan_create_notifier.dart';
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

  Future<void> _calculateQuote() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(loanCreateNotifierProvider.notifier)
        .calculateQuote(
          principal: _principalController.text.trim(),
          rate: _rateController.text.trim(),
          termMonths: int.parse(_termController.text.trim()),
          paymentsPerMonth: _paymentsPerMonth,
          firstDueDate: _firstDueDate,
        );
    if (!mounted) return;
    final error = ref.read(loanCreateNotifierProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(loanCreateNotifierProvider).isSubmitting;
    final quoteState = ref.watch(loanCreateNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/borrowers');
            }
          },
        ),
        title: const Text('Create Loan'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Consumer(
              builder: (context, ref, child) {
                final recommendationAsync = ref.watch(
                  borrowerRecommendationProvider(widget.borrowerId),
                );
                return recommendationAsync.when(
                  data: (rec) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: BorrowerRecommendationCard(
                      recommendation: rec,
                      onApplyRecommended: isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _principalController.text =
                                    rec.maxRecommendedPrincipal;
                                final rateVal =
                                    (double.tryParse(
                                          rec.suggestedMonthlyRate,
                                        ) ??
                                        0.03) *
                                    100;
                                _rateController.text = rateVal.toStringAsFixed(
                                  rateVal.truncateToDouble() == rateVal ? 0 : 1,
                                );
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Applied recommended loan principal & interest rate!',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                    ),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
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
            OutlinedButton.icon(
              onPressed: quoteState.isCalculating ? null : _calculateQuote,
              icon: quoteState.isCalculating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calculate_outlined),
              label: Text(
                quoteState.isCalculating ? 'Calculating…' : 'Calculate Quote',
              ),
            ),
            if (quoteState.quote case final quote?) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loan Quote',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Payment: \$${quote.regularPaymentAmount}'),
                      Text('Total interest: \$${quote.totalInterest}'),
                      Text('Total repayment: \$${quote.totalRepayment}'),
                      Text('Payments: ${quote.numberOfPayments}'),
                      Text('Estimated final due date: ${quote.finalDueDate}'),
                      const SizedBox(height: 6),
                      const Text(
                        'Estimate only. No loan has been created.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: isSubmitting ? null : _submit,
          icon: isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(isSubmitting ? 'Creating\u2026' : 'Create Loan'),
        ),
      ),
    );
  }
}
