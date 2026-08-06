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
    required this.method,
    required this.onMethodChanged,
    required this.receiptController,
    this.sessionOptions = const {},
    this.collectionSessionId,
    this.onSessionChanged,
    this.onAutoGenerateReceipt,
    this.onAutoGenerateNote,
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
  final String method;
  final ValueChanged<String?> onMethodChanged;
  final TextEditingController receiptController;
  final Map<String, String> sessionOptions;
  final String? collectionSessionId;
  final ValueChanged<String?>? onSessionChanged;
  final VoidCallback? onAutoGenerateReceipt;
  final VoidCallback? onAutoGenerateNote;

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
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(
                  labelText: 'Payment method',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
                  DropdownMenuItem(
                    value: 'mobile_money',
                    child: Text('Mobile money'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: working ? null : onMethodChanged,
              ),
              if (method == 'cash') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: collectionSessionId,
                  decoration: const InputDecoration(
                    labelText: 'Active collection session',
                    prefixIcon: Icon(Icons.point_of_sale_outlined),
                  ),
                  items: sessionOptions.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(growable: false),
                  validator: (value) => value == null
                      ? 'An active collection session is required for cash'
                      : null,
                  onChanged: working ? null : onSessionChanged,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: receiptController,
                  enabled: !working,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: 'Receipt number (Auto-generated)',
                    prefixIcon: const Icon(Icons.receipt_long_outlined),
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.autorenew, size: 20),
                      tooltip: 'Auto-generate new receipt number',
                      onPressed: working ? null : onAutoGenerateReceipt,
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Receipt number is required for cash'
                      : null,
                  onChanged: (_) => onFieldChange(),
                ),
              ],
              if (installmentAmount != null || payoffAmount != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Recommended amounts (Tap to select):',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (installmentAmount != null)
                      ActionChip(
                        avatar: const Icon(Icons.event_note, size: 16),
                        label: Text(
                          '${formatCurrency(installmentAmount!)} Installment',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onPressed: working
                            ? null
                            : () {
                                amountController.text = installmentAmount!;
                                onFieldChange();
                              },
                      ),
                    if (payoffAmount != null)
                      ActionChip(
                        avatar: const Icon(Icons.savings_outlined, size: 16),
                        label: Text(
                          '${formatCurrency(payoffAmount!)} Full Payoff',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        backgroundColor: Colors.teal.withValues(alpha: 0.18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onPressed: working
                            ? null
                            : () {
                                amountController.text = payoffAmount!;
                                onFieldChange();
                              },
                      ),
                  ],
                ),
              ],
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
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Regular installment via Cash',
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF0D9488),
                      size: 20,
                    ),
                    tooltip: 'AI Auto-generate payment note',
                    onPressed: working ? null : onAutoGenerateNote,
                  ),
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
