import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/models/payment.dart';

class PaymentHistorySection extends StatelessWidget {
  const PaymentHistorySection({
    super.key,
    required this.payments,
    required this.working,
    this.onReverse,
    this.onSendToBorrower,
  });

  final List<LoanPayment> payments;
  final bool working;
  final ValueChanged<LoanPayment>? onReverse;
  final ValueChanged<LoanPayment>? onSendToBorrower;

  @override
  Widget build(BuildContext context) {
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
          _PaymentTile(
            payment: payments[i],
            isReversed: reversedIds.contains(payments[i].id),
            onReverse:
                i == 0 && latestCanReverse && !working && onReverse != null
                ? () => onReverse!(payments[i])
                : null,
            onSendToBorrower:
                payments[i].entryType == 'Payment' &&
                    !reversedIds.contains(payments[i].id)
                ? () => onSendToBorrower?.call(payments[i])
                : null,
          ),
      ],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.isReversed,
    this.onReverse,
    this.onSendToBorrower,
  });

  final LoanPayment payment;
  final bool isReversed;
  final VoidCallback? onReverse;
  final VoidCallback? onSendToBorrower;

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        Expanded(child: Text(formatCurrency(payment.amount))),
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
          Chip(
            label: const Text('Payment'),
            backgroundColor: Colors.green.withValues(alpha: 0.1),
            side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );

    if (isReversed) {
      return Card(
        child: ListTile(
          title: header,
          subtitle: Text(formatDateShort(payment.effectiveDate)),
        ),
      );
    }

    return Card(
      child: ExpansionTile(
        title: header,
        subtitle: Text(formatDateShort(payment.effectiveDate)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          InfoRow(
            'Interest',
            formatCurrency(payment.allocation.appliedInterest),
          ),
          InfoRow(
            'Principal',
            formatCurrency(payment.allocation.appliedPrincipal),
          ),
          InfoRow(
            'Balance after',
            formatCurrency(payment.allocation.principalAfter),
          ),
          InfoRow('Financial date', formatDateShort(payment.effectiveDate)),
          InfoRow('Recorded at', formatDateShort(payment.createdAt)),
          if (payment.note case final note?)
            Align(alignment: Alignment.centerLeft, child: Text('Note: $note')),
          if (onReverse != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onReverse,
              icon: const Icon(Icons.undo),
              label: const Text('Reverse Payment'),
            ),
          ],
          if (onSendToBorrower != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onSendToBorrower,
              icon: const Icon(Icons.send_to_mobile_outlined),
              label: const Text('Send Receipt to Borrower'),
            ),
          ],
        ],
      ),
    );
  }
}
