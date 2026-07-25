import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/models/loan.dart';

/// Progress Section displaying Loan Completion %, Paid vs Remaining bar, and Installment Counter.
class LoanProgressSection extends StatelessWidget {
  final Loan loan;

  const LoanProgressSection({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final total = double.tryParse(loan.originalPrincipal) ?? 0;
    final outstanding = double.tryParse(loan.outstandingPrincipal) ?? 0;
    final paid = total > outstanding ? total - outstanding : 0.0;
    final percentPaid = total > 0
        ? ((paid / total) * 100).clamp(0.0, 100.0)
        : 0.0;

    int paidCount = 0;
    for (final inst in loan.installments) {
      if (inst.status == 'Paid') paidCount++;
    }
    final totalInstallments = loan.installments.length;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.donut_large_outlined,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loan Repayment Progress',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${percentPaid.round()}% Paid',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: percentPaid >= 100
                        ? Colors.green
                        : colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percentPaid / 100,
                minHeight: 10,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentPaid >= 100 ? Colors.green : colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SubDetail(
                  label: 'Paid Capital',
                  value: formatCurrency(paid.toStringAsFixed(2)),
                  color: Colors.green,
                ),
                _SubDetail(
                  label: 'Remaining Principal',
                  value: formatCurrency(outstanding.toStringAsFixed(2)),
                  color: colorScheme.primary,
                ),
                _SubDetail(
                  label: 'Installments',
                  value: '$paidCount of $totalInstallments',
                  color: colorScheme.secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubDetail extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SubDetail({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
