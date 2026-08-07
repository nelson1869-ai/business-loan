import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';
import 'package:lending_nelson/core/utils/formatters.dart';

import '../../../settings/data/business_setting_repository.dart';
import '../../../settings/providers/business_setting_provider.dart';

class BusinessLoanConfigSheet extends ConsumerStatefulWidget {
  const BusinessLoanConfigSheet({super.key});

  @override
  ConsumerState<BusinessLoanConfigSheet> createState() =>
      _BusinessLoanConfigSheetState();
}

class _BusinessLoanConfigSheetState
    extends ConsumerState<BusinessLoanConfigSheet> {
  final _businessName = TextEditingController();
  final _currencyCode = TextEditingController();
  final _receiptFooter = TextEditingController();

  /// Displayed as percentage (e.g. "10"), stored on backend as "0.10".
  /// Empty string means no estimate rate configured.
  final _estimateRate = TextEditingController();

  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(businessSettingProvider, (_, next) {
      next.whenData((settings) {
        if (_initialized) return;
        _initialized = true;
        _businessName.text = settings.businessName;
        _currencyCode.text = settings.currencyCode;
        _receiptFooter.text = settings.receiptFooter;
        // Convert stored decimal rate to display percentage.
        // formatInterestRate("0.10") → "10%" → strip "%" → "10"
        final raw = settings.defaultMonthlyEstimateRate;
        _estimateRate.text =
            raw == null ? '' : formatInterestRate(raw).replaceAll('%', '').trim();
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _businessName.dispose();
    _currencyCode.dispose();
    _receiptFooter.dispose();
    _estimateRate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(businessSettingProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Business Presentation Settings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'These values affect labels and receipts only. Loan calculations, '
            'penalties, rounding, and payment allocation are unchanged.',
          ),
          const SizedBox(height: 16),
          if (settingsAsync.isLoading)
            const AppCardSkeleton()
          else if (settingsAsync.hasError)
            AppErrorState(
              error:
                  'Owner authorization is required to save changes. Check your connection and try again.',
              onRetry: () => ref.invalidate(businessSettingProvider),
            )
          else ...[
            TextField(
              controller: _businessName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Business name',
                prefixIcon: Icon(Icons.apartment_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _currencyCode,
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'ISO currency code',
                helperText: 'For example: PHP',
                prefixIcon: Icon(Icons.currency_exchange_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _receiptFooter,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Receipt footer',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Borrower Loan Estimates',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            const Text(
              'When set, borrowers can preview an estimated payment schedule '
              'before submitting a loan request. The final interest rate is '
              'still determined by you when creating the actual loan.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _estimateRate,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Default Monthly Estimate Rate',
                suffixText: '%',
                prefixIcon: Icon(Icons.percent_outlined),
                helperText: 'Leave blank to disable borrower estimates',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save Settings'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _businessName.text.trim();
    final currency = _currencyCode.text.trim().toUpperCase();
    if (name.isEmpty || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      _message('Enter a business name and a three-letter currency code.');
      return;
    }

    // Validate the estimate rate field if non-empty.
    String? decimalRate;
    final rateText = _estimateRate.text.trim();
    if (rateText.isNotEmpty) {
      final rateValue = double.tryParse(rateText);
      if (rateValue == null || rateValue < 0) {
        _message('Enter a valid non-negative percentage for the estimate rate, or leave it blank.');
        return;
      }
      // Convert display percentage → exact decimal string (e.g. "10" → "0.10").
      decimalRate = percentageToDecimalRate(rateText);
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(businessSettingRepositoryProvider)
          .save(
            businessName: name,
            currencyCode: currency,
            receiptFooter: _receiptFooter.text.trim(),
            defaultMonthlyEstimateRate: decimalRate,
          );
      ref.invalidate(businessSettingProvider);
      if (mounted) _message('Business settings saved.');
    } catch (_) {
      if (mounted) _message('Could not save business settings.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
