import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/formatters.dart';

String? validatePaymentAmount(String? value) {
  final text = value?.trim() ?? '';
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text) ||
      RegExp(r'^0+(?:\.0{1,2})?$').hasMatch(text)) {
    return 'Enter an amount greater than zero with up to 2 decimals';
  }
  return null;
}

/// Large keypad-friendly payment input field with quick preset amount chips.
class PaymentEntrySection extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController amountController;
  final bool working;
  final String? installmentAmount;
  final String? outstandingPrincipal;
  final VoidCallback onFieldChange;
  final VoidCallback onPreview;

  const PaymentEntrySection({
    super.key,
    required this.formKey,
    required this.amountController,
    required this.working,
    this.installmentAmount,
    this.outstandingPrincipal,
    required this.onFieldChange,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = double.tryParse(installmentAmount ?? '0') ?? 0;
    final halfDue = due > 0 ? (due / 2).toStringAsFixed(2) : null;

    return Form(
      key: formKey,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.point_of_sale,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rapid Payment Entry',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Preset Amount Action Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (installmentAmount != null) ...[
                    ActionChip(
                      avatar: const Icon(Icons.check_circle_outline, size: 16),
                      label: Text(
                        'Full Due (${formatCurrency(installmentAmount!)})',
                      ),
                      onPressed: working
                          ? null
                          : () {
                              amountController.text = installmentAmount!;
                              onFieldChange();
                            },
                    ),
                    if (halfDue != null)
                      ActionChip(
                        avatar: const Icon(Icons.pie_chart_outline, size: 16),
                        label: Text('Half Due (${formatCurrency(halfDue)})'),
                        onPressed: working
                            ? null
                            : () {
                                amountController.text = halfDue;
                                onFieldChange();
                              },
                      ),
                  ],
                  if (outstandingPrincipal != null)
                    ActionChip(
                      avatar: const Icon(Icons.stars_outlined, size: 16),
                      label: const Text('Full Payoff'),
                      onPressed: working
                          ? null
                          : () {
                              amountController.text = outstandingPrincipal!;
                              onFieldChange();
                            },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Large Numeric Amount Input Field
              TextFormField(
                controller: amountController,
                enabled: !working,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                decoration: InputDecoration(
                  labelText: 'Payment Amount (\$)',
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.attach_money, size: 28),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.15,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                validator: validatePaymentAmount,
                onChanged: (_) => onFieldChange(),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: working ? null : onPreview,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Calculate & Preview Allocation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
