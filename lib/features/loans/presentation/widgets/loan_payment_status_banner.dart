import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/models/loan.dart';

/// Payment Status Banner alerting collection officers of overdue status or payment health.
class LoanPaymentStatusBanner extends StatelessWidget {
  final Loan loan;
  final VoidCallback? onPayNow;

  const LoanPaymentStatusBanner({super.key, required this.loan, this.onPayNow});

  @override
  Widget build(BuildContext context) {
    if (loan.status == 'Draft' || loan.status == 'Cancelled') {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isFullyPaid =
        loan.status == 'Paid' ||
        (double.tryParse(loan.outstandingPrincipal) ?? 0) == 0;
    final isOverdue = loan.status == 'Overdue';

    if (isFullyPaid) {
      return Material(
        color: Colors.green.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.green, width: 1.5),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Loan Fully Paid Off — Zero Balance Outstanding',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isOverdue) {
      // Find overdue amount and days
      double overdueAmt = 0;
      int daysOverdue = 0;
      for (final inst in loan.installments) {
        if (inst.status == 'Overdue') {
          overdueAmt += double.tryParse(inst.expectedPayment) ?? 0;
          final due = DateTime.tryParse(inst.dueDate);
          if (due != null) {
            final diff = DateTime.now().difference(due).inDays;
            if (diff > daysOverdue) daysOverdue = diff;
          }
        }
      }

      return Material(
        color: Colors.red.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.red.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ Payment Overdue (${daysOverdue > 0 ? daysOverdue : 1} Days Late)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Amount Due: ${formatCurrency(overdueAmt > 0 ? overdueAmt.toStringAsFixed(2) : loan.outstandingPrincipal)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Next Action: Contact borrower immediately for payment collection.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              if (onPayNow != null)
                FilledButton(
                  onPressed: onPayNow,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  child: const Text('Pay Now', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Loan Current — Next payment due on ${formatDateShort(loan.firstDueDate)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
