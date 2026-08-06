import 'package:flutter/material.dart';

/// Executive Financial Overview widget for Business Owners and Admins.
class OwnerFinancialSummaryCard extends StatelessWidget {
  final String totalPrincipalDisbursed;
  final String monthlyInterestIncome;
  final String outstandingBalance;
  final String averageInterestRate;

  const OwnerFinancialSummaryCard({
    super.key,
    required this.totalPrincipalDisbursed,
    required this.monthlyInterestIncome,
    required this.outstandingBalance,
    required this.averageInterestRate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFF1E1B4B), const Color(0xFF312E81)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Owner & Admin Portfolio Overview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final tiles = <Widget>[
                  _buildFinancialTile(
                    label: 'Active Disbursed',
                    value: _formatCurrency(totalPrincipalDisbursed),
                    subtitle: 'Active loans principal',
                    icon: Icons.payments_outlined,
                    iconColor: Colors.tealAccent,
                  ),
                  _buildFinancialTile(
                    label: 'Monthly Interest',
                    value: _formatCurrency(monthlyInterestIncome),
                    subtitle: 'Projected income / mo',
                    icon: Icons.trending_up,
                    iconColor: Colors.lightGreenAccent,
                  ),
                  _buildFinancialTile(
                    label: 'Active Outstanding',
                    value: _formatCurrency(outstandingBalance),
                    subtitle: 'Capital out in field',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: Colors.lightBlueAccent,
                  ),
                  _buildFinancialTile(
                    label: 'Avg Portfolio Rate',
                    value: averageInterestRate,
                    subtitle: 'Weighted monthly yield',
                    icon: Icons.percent,
                    iconColor: Colors.amberAccent,
                  ),
                ];
                if (constraints.maxWidth < 360) {
                  return Column(
                    children: [
                      for (var index = 0; index < tiles.length; index++) ...[
                        SizedBox(width: double.infinity, child: tiles[index]),
                        if (index != tiles.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  );
                }
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: tiles[0]),
                        const SizedBox(width: 12),
                        Expanded(child: tiles[1]),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: tiles[2]),
                        const SizedBox(width: 12),
                        Expanded(child: tiles[3]),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialTile({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(String amount) {
    final val = double.tryParse(amount) ?? 0.0;
    if (val >= 1000000) {
      return '₱${(val / 1000000).toStringAsFixed(2)}M';
    }
    if (val >= 1000) {
      return '₱${(val / 1000).toStringAsFixed(1)}K';
    }
    return '₱${val.toStringAsFixed(2)}';
  }
}
