import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/models/installment.dart';
import '../../domain/models/loan.dart';

/// Responsive Grid of equal-height financial summary metric cards.
class LoanFinancialSummaryCards extends StatelessWidget {
  final Loan loan;

  const LoanFinancialSummaryCards({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final origPrincipal = double.tryParse(loan.originalPrincipal) ?? 0;
    final outPrincipal = double.tryParse(loan.outstandingPrincipal) ?? 0;
    final paidAmount = origPrincipal - outPrincipal;

    // Calculate total interest across installments
    double totalInterest = 0;
    for (final inst in loan.installments) {
      totalInterest += double.tryParse(inst.expectedInterest) ?? 0;
    }
    final totalLoanAmount = origPrincipal + totalInterest;

    // Find next due installment & overdue days
    Installment? nextDue;
    int daysOverdue = 0;
    for (final inst in loan.installments) {
      if (inst.status == 'Overdue') {
        final due = DateTime.tryParse(inst.dueDate);
        if (due != null) {
          final diff = DateTime.now().difference(due).inDays;
          if (diff > daysOverdue) daysOverdue = diff;
        }
      }
      if (nextDue == null && inst.status != 'Paid') {
        nextDue = inst;
      }
    }

    final nextPaymentStr = nextDue != null
        ? formatCurrency(nextDue.expectedPayment)
        : '\$0.00';
    final nextDueDateStr = nextDue != null
        ? formatDateShort(nextDue.dueDate)
        : 'Fully Paid';

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
            _MetricCard(
              label: 'Remaining Balance',
              value: formatCurrency(outPrincipal.toStringAsFixed(2)),
              icon: Icons.account_balance_wallet_outlined,
              color: theme.colorScheme.primary,
            ),
            _MetricCard(
              label: 'Paid Amount',
              value: formatCurrency(paidAmount.toStringAsFixed(2)),
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
            _MetricCard(
              label: 'Principal',
              value: formatCurrency(origPrincipal.toStringAsFixed(2)),
              icon: Icons.payments_outlined,
              color: theme.colorScheme.secondary,
            ),
            _MetricCard(
              label: 'Total Loan',
              value: formatCurrency(totalLoanAmount.toStringAsFixed(2)),
              icon: Icons.summarize_outlined,
              color: theme.colorScheme.tertiary,
            ),
            _MetricCard(
              label: 'Next Payment',
              value: nextPaymentStr,
              icon: Icons.schedule_send_outlined,
              color: Colors.teal,
            ),
            _MetricCard(
              label: 'Next Due Date',
              value: nextDueDateStr,
              icon: Icons.calendar_month_outlined,
              color: Colors.indigo,
            ),
            _MetricCard(
              label: 'Days Overdue',
              value: daysOverdue > 0 ? '$daysOverdue Days' : '0 Days',
              icon: Icons.timer_outlined,
              color: daysOverdue > 0 ? Colors.red : Colors.green,
            ),
            _MetricCard(
              label: 'Monthly Rate',
              value: '${formatInterestRate(loan.monthlyRate)}/mo',
              icon: Icons.percent,
              color: Colors.amber.shade800,
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
