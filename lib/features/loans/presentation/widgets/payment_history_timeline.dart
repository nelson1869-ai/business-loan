import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/models/payment.dart';

/// Timeline of payment receipt history with sync status badges and reversal actions.
class PaymentHistoryTimeline extends StatelessWidget {
  final List<LoanPayment> payments;
  final bool working;
  final void Function(LoanPayment) onReverse;

  const PaymentHistoryTimeline({
    super.key,
    required this.payments,
    required this.working,
    required this.onReverse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (payments.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  'No Payment Receipts Found',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recorded payments for this loan will appear here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final reversedIds = payments
        .map((p) => p.reversalOfPaymentId)
        .whereType<String>()
        .toSet();

    final latestCanReverse =
        payments.first.entryType == 'Payment' &&
        !reversedIds.contains(payments.first.id);

    return Column(
      children: [
        for (var i = 0; i < payments.length; i++)
          _TimelineTile(
            payment: payments[i],
            isReversed: reversedIds.contains(payments[i].id),
            onReverse: i == 0 && latestCanReverse && !working
                ? () => onReverse(payments[i])
                : null,
          ),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final LoanPayment payment;
  final bool isReversed;
  final VoidCallback? onReverse;

  const _TimelineTile({
    required this.payment,
    required this.isReversed,
    this.onReverse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortId = payment.id.length >= 8
        ? payment.id.substring(0, 8)
        : payment.id;

    final header = Row(
      children: [
        Expanded(
          child: Text(
            formatCurrency(payment.amount),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        if (payment.entryType == 'Reversal')
          Chip(
            label: const Text('Reversal'),
            backgroundColor: Colors.orange.withValues(alpha: 0.15),
            side: BorderSide(color: Colors.orange.withValues(alpha: 0.4)),
            visualDensity: VisualDensity.compact,
          )
        else if (isReversed)
          Chip(
            label: const Text('Reversed'),
            backgroundColor: Colors.red.withValues(alpha: 0.08),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
            visualDensity: VisualDensity.compact,
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done, size: 12, color: Colors.teal),
                SizedBox(width: 4),
                Text(
                  'Synced',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (isReversed) {
      return Card(
        child: ListTile(
          title: header,
          subtitle: Text(
            'Receipt #RCP-$shortId · ${formatDateShort(payment.effectiveDate)}',
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: header,
        subtitle: Text(
          'Receipt #RCP-$shortId · ${formatDateShort(payment.effectiveDate)}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _DetailRow(
            'Applied Interest',
            formatCurrency(payment.allocation.appliedInterest),
          ),
          _DetailRow(
            'Applied Principal',
            formatCurrency(payment.allocation.appliedPrincipal),
          ),
          _DetailRow(
            'Balance Remaining',
            formatCurrency(payment.allocation.principalAfter),
          ),
          _DetailRow('Effective Date', formatDateShort(payment.effectiveDate)),
          if (payment.note != null && payment.note!.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Note: ${payment.note}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          if (onReverse != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onReverse,
              icon: const Icon(Icons.undo),
              label: const Text('Reverse Payment'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
