import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/models/payment.dart';

/// Receipt Preview Card displaying a summary before final confirmation.
class PaymentReceiptPreviewCard extends StatelessWidget {
  final PaymentPreview preview;
  final bool working;
  final VoidCallback onConfirm;

  const PaymentReceiptPreviewCard({
    super.key,
    required this.preview,
    required this.working,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPayoff = (double.tryParse(preview.principalAfter) ?? 0) == 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.green.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.green, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Official Receipt Summary',
                    maxLines: 2,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPayoff ? 'FULL PAYOFF' : 'PARTIAL PAYMENT',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _ReceiptRow(
              label: 'Total Amount Collected',
              value: formatCurrency(preview.paymentAmount),
              isBold: true,
            ),
            const SizedBox(height: 6),
            _ReceiptRow(
              label: 'Interest Portion',
              value: formatCurrency(preview.appliedInterest),
            ),
            const SizedBox(height: 6),
            _ReceiptRow(
              label: 'Principal Portion',
              value: formatCurrency(preview.appliedPrincipal),
            ),
            const SizedBox(height: 6),
            _ReceiptRow(
              label: 'Balance After Payment',
              value: formatCurrency(preview.principalAfter),
            ),
            const SizedBox(height: 16),
            // Primary Confirm Action Button
            FilledButton.icon(
              onPressed: working ? null : onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: working
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                isPayoff
                    ? 'Confirm & Record Full Payoff'
                    : 'Confirm & Save Payment',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? theme.colorScheme.primary : null,
            ),
          ),
        ),
      ],
    );
  }
}
