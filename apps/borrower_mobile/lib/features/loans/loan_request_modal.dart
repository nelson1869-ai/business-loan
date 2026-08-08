import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/core/api/api_error.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:dio/dio.dart';

class LoanRequestModal extends ConsumerStatefulWidget {
  const LoanRequestModal({super.key});

  /// Launch the loan request modal as a modern bottom sheet.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LoanRequestModal(),
    );
  }

  @override
  ConsumerState<LoanRequestModal> createState() => _LoanRequestModalState();
}

class _LoanRequestModalState extends ConsumerState<LoanRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  int _termMonths = 1;
  String _paymentFrequency = 'monthly';
  bool _working = false;

  // ---- Quote / estimate state ----
  Map<String, dynamic>? _quoteResult;
  bool _quoteLoading = false;
  bool _quoteIsStale = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  void _invalidateQuote() {
    if (_quoteResult == null && !_quoteIsStale) return;
    setState(() {
      _quoteResult = null;
      _quoteIsStale = true;
    });
  }

  Future<void> _calculateEstimate() async {
    if (_quoteLoading) return;

    final amountText = _amountCtrl.text.trim();
    if (amountText.isEmpty || double.tryParse(amountText) == null) {
      _showMessage('Enter a valid requested amount before calculating an estimate.');
      return;
    }

    setState(() {
      _quoteLoading = true;
      _quoteIsStale = false;
    });

    try {
      final api = ref.read(apiClientProvider);
      final result = await api.post(
        '/api/v1/client/loan-requests/quote',
        data: {
          'requestedAmount': amountText,
          'requestedTermMonths': _termMonths,
          'requestedPaymentFrequency': _paymentFrequency,
        },
      );
      if (mounted) {
        setState(() {
          _quoteResult = result;
          _quoteIsStale = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) _showMessage(ApiError.fromDioException(e).message);
    } catch (_) {
      if (mounted) _showMessage('Unable to calculate estimate. Please try again.');
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _formatPercentage(String decimalStr) {
    final value = double.tryParse(decimalStr);
    if (value == null) return decimalStr;
    final pct = value <= 1.0 ? value * 100 : value;
    final formatted = pct.toStringAsFixed(2);
    final trimmed = formatted.replaceFirst(RegExp(r'\.?0+$'), '');
    return '$trimmed%';
  }

  String _formatCurrency(String amount) {
    final value = double.tryParse(amount);
    if (value == null) return 'PHP $amount';
    return 'PHP ${value.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: bottomInset + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Title row
          Row(
            children: [
              const Icon(Icons.request_quote_outlined, color: Color(0xFF0D9488), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Submit Loan Request',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _working ? null : () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Flexible(
            child: SingleChildScrollView(
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
                        prefixText: 'PHP ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _invalidateQuote(),
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
                        if (val != null) {
                          setState(() => _termMonths = val);
                          _invalidateQuote();
                        }
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
                        if (val != null) {
                          setState(() => _paymentFrequency = val);
                          _invalidateQuote();
                        }
                      },
                    ),

                    // ---- Estimate section ----
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: (_quoteLoading || _working) ? null : _calculateEstimate,
                      icon: _quoteLoading
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.calculate_outlined),
                      label: Text(_quoteLoading ? 'Calculating...' : 'Calculate Estimate'),
                    ),

                    if (_quoteIsStale && _quoteResult == null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Form values changed. Recalculate estimate.',
                                style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_quoteResult != null) ...[
                      const SizedBox(height: 12),
                      _buildQuoteResult(theme),
                    ],

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
          ),
          const SizedBox(height: 16),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _working ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteResult(ThemeData theme) {
    final quote = _quoteResult!;
    final available = quote['available'] as bool? ?? false;

    if (!available) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                quote['message'] as String? ??
                    'Loan estimate is currently unavailable. Final terms will be provided by the lender.',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
              ),
            ),
          ],
        ),
      );
    }

    final rate = quote['estimatedMonthlyRate'] as String? ?? '';
    final numPayments = quote['numberOfPayments'] as int? ?? 0;
    final regularAmt = quote['regularPaymentAmount'] as String? ?? '0';
    final totalInterest = quote['totalInterest'] as String? ?? '0';
    final totalRepayment = quote['totalRepayment'] as String? ?? '0';
    final firstDue = quote['provisionalFirstDueDate'] as String? ?? '';
    final finalDue = quote['provisionalFinalDueDate'] as String? ?? '';
    final disclaimer = quote['disclaimer'] as String? ??
        'Estimate only. Future interest may decrease when you pay principal earlier. Final approved terms are determined by the lender.';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: const Color(0xFF0D9488).withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart_outlined, color: Color(0xFF0D9488), size: 18),
                const SizedBox(width: 6),
                Text(
                  'Estimated Loan Preview',
                  style: theme.textTheme.titleSmall?.copyWith(color: const Color(0xFF0D9488)),
                ),
              ],
            ),
            const Divider(height: 16),
            _previewRow('Estimated Monthly Rate', _formatPercentage(rate)),
            _previewRow('Number of Payments', '$numPayments'),
            _previewRow('Est. Payment Amount', _formatCurrency(regularAmt)),
            _previewRow('Estimated Interest', _formatCurrency(totalInterest)),
            _previewRow('Estimated Total Repayment', _formatCurrency(totalRepayment)),
            if (firstDue.isNotEmpty) _previewRow('First Payment (Est.)', firstDue),
            if (finalDue.isNotEmpty) _previewRow('Final Payment (Est.)', finalDue),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                disclaimer,
                style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
