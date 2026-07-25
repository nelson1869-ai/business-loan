import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

/// Visual trend chart cards for Daily Collections & Monthly Loan Disbursement.
class ReportsTrendCharts extends StatelessWidget {
  const ReportsTrendCharts({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Daily Collection & Repayment Bar Visualization
        AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bar_chart_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Daily Collection & Repayment Trend',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  _BarColumn(
                    label: 'Mon',
                    height: 40,
                    amount: '₱1.2k',
                    color: Colors.teal,
                  ),
                  _BarColumn(
                    label: 'Tue',
                    height: 65,
                    amount: '₱2.4k',
                    color: Colors.teal,
                  ),
                  _BarColumn(
                    label: 'Wed',
                    height: 50,
                    amount: '₱1.8k',
                    color: Colors.teal,
                  ),
                  _BarColumn(
                    label: 'Thu',
                    height: 85,
                    amount: '₱3.6k',
                    color: Colors.teal,
                  ),
                  _BarColumn(
                    label: 'Fri',
                    height: 95,
                    amount: '₱4.2k',
                    color: Colors.green,
                  ),
                  _BarColumn(
                    label: 'Sat',
                    height: 30,
                    amount: '₱900',
                    color: Colors.teal,
                  ),
                  _BarColumn(
                    label: 'Sun',
                    height: 20,
                    amount: '₱500',
                    color: Colors.teal,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Monthly Disbursement Trend Card
        AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.show_chart_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Monthly Disbursement & Borrower Growth',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  _BarColumn(
                    label: 'Jan',
                    height: 45,
                    amount: '₱12k',
                    color: Colors.blue,
                  ),
                  _BarColumn(
                    label: 'Feb',
                    height: 60,
                    amount: '₱18k',
                    color: Colors.blue,
                  ),
                  _BarColumn(
                    label: 'Mar',
                    height: 75,
                    amount: '₱25k',
                    color: Colors.blue,
                  ),
                  _BarColumn(
                    label: 'Apr',
                    height: 90,
                    amount: '₱32k',
                    color: Colors.blue,
                  ),
                  _BarColumn(
                    label: 'May',
                    height: 105,
                    amount: '₱40k',
                    color: Colors.purple,
                  ),
                  _BarColumn(
                    label: 'Jun',
                    height: 120,
                    amount: '₱52k',
                    color: Colors.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarColumn extends StatelessWidget {
  final String label;
  final double height;
  final String amount;
  final Color color;

  const _BarColumn({
    required this.label,
    required this.height,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          amount,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
