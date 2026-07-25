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
                  Expanded(
                    child: Text(
                      'Daily Collection & Repayment Trend',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              AppEmptyState(
                icon: Icons.query_stats_outlined,
                title: 'Daily Trend Unavailable',
                description:
                    'Daily collection and repayment history is not available from the connected data source.',
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
                  Expanded(
                    child: Text(
                      'Monthly Disbursement & Borrower Growth',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              AppEmptyState(
                icon: Icons.query_stats_outlined,
                title: 'Monthly Trend Unavailable',
                description:
                    'Monthly disbursement and borrower-growth history is not available from the connected data source.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
