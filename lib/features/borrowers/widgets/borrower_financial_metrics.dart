import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../../loans/domain/models/loan.dart';

/// Responsive Grid of equal-height Financial Metric Cards.
class BorrowerFinancialMetrics extends StatelessWidget {
  final List<Loan> loans;

  const BorrowerFinancialMetrics({super.key, required this.loans});

  @override
  Widget build(BuildContext context) {
    double totalBorrowed = 0;
    double remainingBalance = 0;
    int activeLoansCount = 0;
    String nextPaymentAmount = '\$0.00';
    String nextDueDateStr = 'N/A';
    int daysOverdue = 0;

    for (final loan in loans) {
      final principal = double.tryParse(loan.originalPrincipal) ?? 0;
      final outstanding = double.tryParse(loan.outstandingPrincipal) ?? 0;
      totalBorrowed += principal;

      if (loan.status == 'Active' || loan.status == 'Overdue') {
        activeLoansCount++;
        remainingBalance += outstanding;

        if (nextPaymentAmount == '\$0.00' &&
            loan.regularPaymentAmount.isNotEmpty) {
          nextPaymentAmount = formatCurrency(loan.regularPaymentAmount);
          nextDueDateStr = loan.firstDueDate.length >= 10
              ? loan.firstDueDate.substring(0, 10)
              : loan.firstDueDate;
        }

        for (final inst in loan.installments) {
          if (inst.status == 'Overdue') {
            final due = DateTime.tryParse(inst.dueDate);
            if (due != null) {
              final diff = DateTime.now().difference(due).inDays;
              if (diff > daysOverdue) daysOverdue = diff;
            }
          }
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: constraints.maxWidth > 600 ? 2.2 : 1.8,
          children: [
            _MetricCard(
              label: 'Remaining Balance',
              value: formatCurrency(remainingBalance.toStringAsFixed(2)),
              icon: Icons.account_balance_wallet_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            _MetricCard(
              label: 'Total Borrowed',
              value: formatCurrency(totalBorrowed.toStringAsFixed(2)),
              icon: Icons.payments_outlined,
              color: Theme.of(context).colorScheme.secondary,
            ),
            _MetricCard(
              label: 'Active Loans',
              value: '$activeLoansCount',
              icon: Icons.receipt_long_outlined,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            _MetricCard(
              label: 'Next Payment',
              value: nextPaymentAmount,
              icon: Icons.schedule_send_outlined,
              color: Colors.teal,
            ),
            _MetricCard(
              label: 'Due Date',
              value: nextDueDateStr,
              icon: Icons.calendar_month_outlined,
              color: Colors.indigo,
            ),
            _MetricCard(
              label: 'Days Overdue',
              value: daysOverdue > 0 ? '$daysOverdue Days' : 'None',
              icon: Icons.timer_outlined,
              color: daysOverdue > 0 ? Colors.red : Colors.green,
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
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
