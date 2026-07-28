import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/formatters.dart';
import '../../loans/domain/models/loan.dart';

/// Card showcasing active loan details.
class BorrowerActiveLoanCard extends StatelessWidget {
  final Loan loan;

  const BorrowerActiveLoanCard({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final orig = double.tryParse(loan.originalPrincipal) ?? 0;
    final out = double.tryParse(loan.outstandingPrincipal) ?? 0;
    final ratePct = (double.tryParse(loan.monthlyRate) ?? 0) * 100;
    final dueDate = loan.firstDueDate.length >= 10
        ? loan.firstDueDate.substring(0, 10)
        : loan.firstDueDate;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.credit_score,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Active Loan Overview',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: loan.status.toLowerCase() == 'overdue'
                        ? colorScheme.errorContainer
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    loan.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: loan.status.toLowerCase() == 'overdue'
                          ? colorScheme.onErrorContainer
                          : colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DetailColumn(
                    label: 'Loan Amount',
                    value: formatCurrency(orig.toStringAsFixed(2)),
                  ),
                ),
                Expanded(
                  child: _DetailColumn(
                    label: 'Outstanding Balance',
                    value: formatCurrency(out.toStringAsFixed(2)),
                    isHighlight: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DetailColumn(
                    label: 'Monthly Rate',
                    value: '${ratePct.toStringAsFixed(1)}%/mo',
                  ),
                ),
                Expanded(
                  child: _DetailColumn(label: 'Next Due Date', value: dueDate),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DetailColumn(
                    label: 'Regular Installment',
                    value: formatCurrency(loan.regularPaymentAmount),
                  ),
                ),
                Expanded(
                  child: _DetailColumn(
                    label: 'Collection Officer',
                    value: 'Recorded by system',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/loans/${loan.id}', extra: loan),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('View Full Details & Schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailColumn extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _DetailColumn({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: isHighlight ? theme.colorScheme.primary : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
