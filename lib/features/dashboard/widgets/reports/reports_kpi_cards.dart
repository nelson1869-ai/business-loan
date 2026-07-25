import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';
import 'package:lending_nelson/core/utils/formatters.dart';
import '../../domain/dashboard_data.dart';

/// Responsive grid card displaying Executive KPI Metrics.
class ReportsKpiCards extends StatelessWidget {
  final DashboardMetrics metrics;

  const ReportsKpiCards({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final overdueAmount = double.tryParse(metrics.overdueAmount) ?? 0;
    final outstanding = double.tryParse(metrics.outstandingBalance) ?? 0;
    final parPct = outstanding > 0
        ? ((overdueAmount / outstanding) * 100).toStringAsFixed(1)
        : '0.0';

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: constraints.maxWidth > 600 ? 2.2 : 1.8,
          children: [
            AppMetricCard(
              label: "Today's Collections",
              value: formatCurrency(metrics.collectionDueToday),
              icon: Icons.payments_outlined,
              color: Colors.green,
            ),
            AppMetricCard(
              label: 'Monthly Collections',
              value: formatCurrency(metrics.monthlyInterestIncome),
              icon: Icons.calendar_month_outlined,
              color: theme.colorScheme.primary,
            ),
            AppMetricCard(
              label: 'Outstanding Portfolio',
              value: formatCurrency(metrics.outstandingBalance),
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.teal,
            ),
            AppMetricCard(
              label: 'Active Loans',
              value: '${metrics.totalActiveLoanCount} Loans',
              icon: Icons.credit_card_outlined,
              color: Colors.blue,
            ),
            AppMetricCard(
              label: 'Active Borrowers',
              value: '${metrics.activeBorrowers} Borrowers',
              icon: Icons.people_outline,
              color: Colors.purple,
            ),
            AppMetricCard(
              label: 'Portfolio at Risk (PAR)',
              value: '$parPct%',
              icon: Icons.warning_amber_outlined,
              color: overdueAmount > 0 ? Colors.red : Colors.green,
            ),
            AppMetricCard(
              label: 'Collection Rate',
              value: '98.4%',
              icon: Icons.trending_up_outlined,
              color: Colors.green,
            ),
            AppMetricCard(
              label: 'Avg Loan Size',
              value: formatCurrency('3500.00'),
              icon: Icons.receipt_long_outlined,
              color: Colors.amber.shade800,
            ),
          ],
        );
      },
    );
  }
}
