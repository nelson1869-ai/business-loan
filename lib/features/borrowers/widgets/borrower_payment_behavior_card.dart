import 'package:flutter/material.dart';
import '../../loans/domain/models/loan.dart';

/// Analytics card presenting payment behavior, punctuality history, and delay indicators.
class BorrowerPaymentBehaviorCard extends StatelessWidget {
  final List<Loan> loans;

  const BorrowerPaymentBehaviorCard({super.key, required this.loans});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    int onTime = 0;
    int late = 0;
    int maxDelay = 0;

    for (final loan in loans) {
      for (final inst in loan.installments) {
        if (inst.status == 'Paid') {
          onTime++;
        } else if (inst.status == 'Overdue') {
          late++;
          final due = DateTime.tryParse(inst.dueDate);
          if (due != null) {
            final delay = DateTime.now().difference(due).inDays;
            if (delay > maxDelay) maxDelay = delay;
          }
        }
      }
    }

    final total = onTime + late;
    final punctualityPct = total > 0 ? ((onTime / total) * 100).round() : 100;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.query_stats_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Payment Punctuality & Behavior Analytics',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Historical Punctuality Rate',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$punctualityPct%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: punctualityPct >= 80
                        ? Colors.green
                        : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: punctualityPct / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: punctualityPct >= 80 ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'On-Time Payments',
                  value: '$onTime',
                  color: Colors.green,
                ),
                _StatItem(
                  label: 'Late / Overdue',
                  value: '$late',
                  color: late > 0 ? Colors.red : Colors.green,
                ),
                _StatItem(
                  label: 'Max Delay Days',
                  value: maxDelay > 0 ? '$maxDelay Days' : '0 Days',
                  color: maxDelay > 0 ? Colors.red : Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
