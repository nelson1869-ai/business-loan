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

class PaymentFormCard extends StatelessWidget {
  const PaymentFormCard({
    super.key,
    required this.formKey,
    required this.amountController,
    required this.noteController,
    required this.dateLabel,
    required this.working,
    required this.onPickDate,
    required this.onPreview,
    required this.onFieldChange,
    required this.theme,
    this.installmentAmount,
    this.payoffAmount,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController amountController;
  final TextEditingController noteController;
  final String dateLabel;
  final bool working;
  final VoidCallback onPickDate;
  final VoidCallback onPreview;
  final VoidCallback onFieldChange;
  final ThemeData theme;
  final String? installmentAmount;
  final String? payoffAmount;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Record a payment', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              if (installmentAmount != null || payoffAmount != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (installmentAmount != null)
                      ActionChip(
                        label: Text(
                          '${formatCurrency(installmentAmount!)} Scheduled Installment',
                        ),
                        onPressed: working
                            ? null
                            : () {
                                amountController.text = installmentAmount!;
                                onFieldChange();
                              },
                      ),
                    if (payoffAmount != null)
                      ActionChip(
                        label: Text(
                          '${formatCurrency(payoffAmount!)} Full Payoff',
                        ),
                        onPressed: working
                            ? null
                            : () {
                                amountController.text = payoffAmount!;
                                onFieldChange();
                              },
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                enabled: !working,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.payments_outlined),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Effective date'),
                subtitle: Text(dateLabel),
                trailing: const Icon(Icons.edit_calendar),
                onTap: working ? null : onPickDate,
              ),
              TextField(
                controller: noteController,
                enabled: !working,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  counterText: '',
                ),
                onChanged: (_) => onFieldChange(),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: working ? null : onPreview,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Preview Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
