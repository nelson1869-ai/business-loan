import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';
import 'package:lending_nelson/core/utils/formatters.dart';
import '../../domain/dashboard_data.dart';
import '../../domain/financial_report.dart';

/// Responsive grid card displaying Executive KPI Metrics.
class ReportsKpiCards extends StatelessWidget {
  final DashboardMetrics metrics;
  final FinancialReport report;

  const ReportsKpiCards({
    super.key,
    required this.metrics,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final overdueAmount = double.tryParse(report.overdueAmount) ?? 0;

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
              label: 'Due Today',
              value: formatCurrency(metrics.collectionDueToday),
              icon: Icons.payments_outlined,
              color: Colors.green,
            ),
            AppMetricCard(
              label: 'Monthly Interest',
              value: formatCurrency(report.interestEarned),
              icon: Icons.calendar_month_outlined,
              color: theme.colorScheme.primary,
            ),
            AppMetricCard(
              label: 'Outstanding Portfolio',
              value: formatCurrency(report.outstandingPortfolio),
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
              value:
                  '${metrics.activeBorrowers} '
                  '${metrics.activeBorrowers == 1 ? 'Borrower' : 'Borrowers'}',
              icon: Icons.people_outline,
              color: Colors.purple,
            ),
            AppMetricCard(
              label: 'Portfolio at Risk (PAR)',
              value: '${report.portfolioAtRisk}%',
              icon: Icons.warning_amber_outlined,
              color: overdueAmount > 0 ? Colors.red : Colors.green,
            ),
            AppMetricCard(
              label: 'Collection Rate',
              value: 'Unavailable',
              icon: Icons.info_outline,
              color: theme.colorScheme.outline,
            ),
            AppMetricCard(
              label: 'Avg Loan Size',
              value: 'Unavailable',
              icon: Icons.info_outline,
              color: theme.colorScheme.outline,
            ),
          ],
        );
      },
    );
  }
}
