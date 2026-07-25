import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../loans/domain/models/loan.dart';

/// Responsive grid card displaying lifetime financial snapshot & relationship summary metrics.
class BorrowerFinancialSnapshot extends StatelessWidget {
  final List<Loan> loans;

  const BorrowerFinancialSnapshot({super.key, required this.loans});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    double totalBorrowed = 0;
    double totalPaid = 0;
    double currentBalance = 0;
    double advanceCredit = 0;

    for (final loan in loans) {
      totalBorrowed += double.tryParse(loan.originalPrincipal) ?? 0;
      currentBalance += double.tryParse(loan.outstandingPrincipal) ?? 0;
      advanceCredit += double.tryParse(loan.unappliedCredit) ?? 0;
      for (final inst in loan.installments) {
        totalPaid += double.tryParse(inst.paidAmount) ?? 0;
      }
    }

    final lifetimeInterestEstimate = (totalBorrowed * 0.12).toStringAsFixed(2);
    final avgPayment = loans.isNotEmpty
        ? (totalPaid / loans.length).toStringAsFixed(2)
        : '0.00';

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
            _MetricTile(
              label: 'Total Borrowed',
              value: formatCurrency(totalBorrowed.toStringAsFixed(2)),
              icon: Icons.payments_outlined,
              color: theme.colorScheme.primary,
            ),
            _MetricTile(
              label: 'Total Repaid',
              value: formatCurrency(totalPaid.toStringAsFixed(2)),
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
            _MetricTile(
              label: 'Current Outstanding',
              value: formatCurrency(currentBalance.toStringAsFixed(2)),
              icon: Icons.account_balance_wallet_outlined,
              color: currentBalance > 0 ? Colors.orange.shade800 : Colors.green,
            ),
            _MetricTile(
              label: 'Advance Credit',
              value: formatCurrency(advanceCredit.toStringAsFixed(2)),
              icon: Icons.stars_outlined,
              color: Colors.purple,
            ),
            _MetricTile(
              label: 'Lifetime Interest',
              value: formatCurrency(lifetimeInterestEstimate),
              icon: Icons.trending_up_outlined,
              color: Colors.amber.shade800,
            ),
            _MetricTile(
              label: 'Avg Payment',
              value: formatCurrency(avgPayment),
              icon: Icons.receipt_long_outlined,
              color: Colors.teal,
            ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
