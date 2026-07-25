import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/models/payment.dart';

/// Live Calculation Panel presenting real-time payment allocation metrics.
class PaymentLiveCalculationPanel extends StatelessWidget {
  final PaymentPreview preview;

  const PaymentLiveCalculationPanel({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final unappliedCredit = double.tryParse(preview.unappliedCredit) ?? 0;
    final overdueDays = preview.overdueDays;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Live Payment Allocation Breakdown',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _CalcRow(
              label: 'Total Payment Amount',
              value: formatCurrency(preview.paymentAmount),
              isBold: true,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 6),
            _CalcRow(
              label: 'Applied to Interest',
              value: formatCurrency(preview.appliedInterest),
              color: Colors.amber.shade800,
            ),
            const SizedBox(height: 6),
            _CalcRow(
              label: 'Applied to Principal',
              value: formatCurrency(preview.appliedPrincipal),
              color: Colors.green,
            ),
            if (unappliedCredit > 0) ...[
              const SizedBox(height: 6),
              _CalcRow(
                label: 'Advance Excess Credit',
                value: formatCurrency(preview.unappliedCredit),
                color: Colors.purple,
              ),
            ],
            const Divider(height: 20),
            _CalcRow(
              label: 'Remaining Principal Balance',
              value: formatCurrency(preview.principalAfter),
              isBold: true,
            ),
            if (overdueDays > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Late payment penalty applied ($overdueDays days late)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalcRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;

  const _CalcRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
