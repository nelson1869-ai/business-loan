import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';
import 'package:lending_nelson/core/utils/formatters.dart';
import '../../domain/financial_report.dart';

/// Card presenting Portfolio Risk Breakdown & PAR Aging analysis.
class ReportsRiskAnalysisCard extends StatelessWidget {
  const ReportsRiskAnalysisCard({super.key, required this.report});

  final FinancialReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSectionCard(
      title: 'Portfolio Risk & PAR Aging Analysis',
      icon: Icons.security_outlined,
      children: [
        _RiskRow(
          label: 'Current',
          value: report.loanAging['current'] ?? '0.00',
          color: Colors.blue,
        ),
        _RiskRow(
          label: 'PAR 1–30 Days',
          value: report.loanAging['1-30'] ?? '0.00',
          color: Colors.amber.shade800,
        ),
        _RiskRow(
          label: 'PAR 31–60 Days',
          value: report.loanAging['31-60'] ?? '0.00',
          color: Colors.orange,
        ),
        _RiskRow(
          label: 'PAR 61–90 Days',
          value: report.loanAging['61-90'] ?? '0.00',
          color: Colors.red,
        ),
        _RiskRow(
          label: 'PAR 91+ Days',
          value: report.loanAging['91+'] ?? '0.00',
          color: Colors.purple,
        ),
        const Divider(height: 20),
        Text(
          'Portfolio at Risk: ${report.portfolioAtRisk}% · '
          '${report.overdueLoanCount} overdue '
          '${report.overdueLoanCount == 1 ? 'loan' : 'loans'}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _RiskRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RiskRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          Text(
            formatCurrency(value),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
