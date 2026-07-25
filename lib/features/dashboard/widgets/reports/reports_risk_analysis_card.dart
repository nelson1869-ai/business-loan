import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

/// Card presenting Portfolio Risk Breakdown & PAR Aging analysis.
class ReportsRiskAnalysisCard extends StatelessWidget {
  const ReportsRiskAnalysisCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSectionCard(
      title: 'Portfolio Risk & PAR Aging Analysis',
      icon: Icons.security_outlined,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            _RiskStat(label: 'Low Risk', value: '82%', color: Colors.blue),
            _RiskStat(label: 'Medium Risk', value: '12%', color: Colors.orange),
            _RiskStat(label: 'High Risk', value: '4%', color: Colors.red),
            _RiskStat(
              label: 'Critical / PAR90',
              value: '2%',
              color: Colors.purple,
            ),
          ],
        ),
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PAR 30 Aging (30-59 Days)', style: theme.textTheme.bodySmall),
            Text(
              '₱12,500.00 (3.2%)',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PAR 60 Aging (60-89 Days)', style: theme.textTheme.bodySmall),
            Text(
              '₱4,200.00 (1.1%)',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PAR 90+ Default Risk (90+ Days)',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              '₱1,800.00 (0.5%)',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RiskStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RiskStat({
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
