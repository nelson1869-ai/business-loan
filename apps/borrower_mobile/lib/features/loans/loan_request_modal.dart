import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/core/api/api_error.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:dio/dio.dart';

class LoanRequestModal extends ConsumerStatefulWidget {
  const LoanRequestModal({super.key});

  @override
  ConsumerState<LoanRequestModal> createState() => _LoanRequestModalState();
}

class _LoanRequestModalState extends ConsumerState<LoanRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  int _termMonths = 1;
  String _paymentFrequency = 'monthly';
  String _repaymentStructure = 'principal_plus_interest';
  bool _working = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _working = true);

    final api = ref.read(apiClientProvider);
    try {
      await api.post(
        '/api/v1/client/loan-requests',
        data: {
          'requestedAmount': _amountCtrl.text.trim(),
          'requestedTermMonths': _termMonths,
          'requestedPaymentFrequency': _paymentFrequency,
          'requestedRepaymentStructure': _repaymentStructure,
          'purpose': _purposeCtrl.text.trim().isEmpty ? null : _purposeCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loan request submitted successfully! Your lender will review it.'),
          backgroundColor: Color(0xFF0D9488),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _working = false);
        final String message = e is DioException
            ? ApiError.fromDioException(e).message
            : (e is ApiError ? e.message : 'Unable to submit your loan request. Please try again.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.request_quote_outlined, color: Color(0xFF0D9488)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Submit Loan Request',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Request a new loan for review by the lender. Official loan terms will be determined upon approval.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Requested Amount (PHP)',
                  prefixText: '₱ ',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _termMonths,
                decoration: const InputDecoration(
                  labelText: 'Loan Duration',
                  border: OutlineInputBorder(),
                ),
                items: [1, 2, 3, 6].map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('$m ${m == 1 ? "Month" : "Months"}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _termMonths = val);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _paymentFrequency,
                decoration: const InputDecoration(
                  labelText: 'Payment Frequency',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'twice_a_month', child: Text('Twice a Month')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _paymentFrequency = val);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _repaymentStructure,
                decoration: const InputDecoration(
                  labelText: 'Repayment Structure',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'principal_plus_interest', child: Text('Principal + Interest')),
                  DropdownMenuItem(value: 'interest_only', child: Text('Interest Only')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _repaymentStructure = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _purposeCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Purpose / Notes (Optional)',
                  hintText: 'e.g. Business expansion, tuition',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _working ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
          child: _working
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Request'),
        ),
      ],
    );
  }
}
