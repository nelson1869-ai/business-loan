import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/models/loan.dart';

/// Responsive Grid of payment summary metric cards for rapid officer assessment.
class PaymentSummaryCards extends StatelessWidget {
  final Loan loan;
  final String? installmentAmount;

  const PaymentSummaryCards({
    super.key,
    required this.loan,
    this.installmentAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final outPrincipal = double.tryParse(loan.outstandingPrincipal) ?? 0;
    final unappliedCredit = double.tryParse(loan.unappliedCredit) ?? 0;

    double overdueAmt = 0;
    int daysLate = 0;
    for (final inst in loan.installments) {
      if (inst.status == 'Overdue') {
        overdueAmt += double.tryParse(inst.expectedPayment) ?? 0;
        final due = DateTime.tryParse(inst.dueDate);
        if (due != null) {
          final diff = DateTime.now().difference(due).inDays;
          if (diff > daysLate) daysLate = diff;
        }
      }
    }

    final nextInstallmentStr = installmentAmount != null
        ? formatCurrency(installmentAmount!)
        : '\$0.00';

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
              label: 'Next Installment',
              value: nextInstallmentStr,
              icon: Icons.schedule_send_outlined,
              color: Colors.teal,
            ),
            _MetricCard(
              label: 'Overdue Amount',
              value: formatCurrency(overdueAmt.toStringAsFixed(2)),
              icon: Icons.warning_amber_rounded,
              color: overdueAmt > 0 ? Colors.red : Colors.green,
            ),
            _MetricCard(
              label: 'Advance Credit',
              value: formatCurrency(unappliedCredit.toStringAsFixed(2)),
              icon: Icons.stars_outlined,
              color: Colors.purple,
            ),
            _MetricCard(
              label: 'Next Due Date',
              value: loan.status == 'Paid'
                  ? 'None'
                  : formatDateShort(loan.firstDueDate),
              icon: Icons.calendar_month_outlined,
              color: Colors.indigo,
            ),
            _MetricCard(
              label: 'Days Late',
              value: daysLate > 0 ? '$daysLate Days' : '0 Days',
              icon: Icons.timer_outlined,
              color: daysLate > 0 ? Colors.red : Colors.green,
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
