import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/models/payment.dart';

class PaymentPreviewCard extends StatelessWidget {
  const PaymentPreviewCard({
    super.key,
    required this.preview,
    required this.working,
    required this.onConfirm,
  });

  final PaymentPreview preview;
  final bool working;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Backend preview', style: theme.textTheme.titleLarge),
            InfoRow('Payment', formatCurrency(preview.paymentAmount)),
            InfoRow('Interest', formatCurrency(preview.appliedInterest)),
            InfoRow('Principal', formatCurrency(preview.appliedPrincipal)),
            InfoRow(
              'Extra above schedule',
              formatCurrency(preview.amountAboveScheduled),
            ),
            InfoRow(
              'Interest remaining',
              formatCurrency(preview.interestAfter),
            ),
            InfoRow(
              'Principal remaining',
              formatCurrency(preview.principalAfter),
            ),
            InfoRow(
              'Next-period interest',
              formatCurrency(preview.nextPeriodInterest),
            ),
            if (preview.overdueDays > 0)
              InfoRow('Days late', '${preview.overdueDays}'),
            if (preview.daysEarly > 0)
              InfoRow('Days early', '${preview.daysEarly}'),
            if (preview.unappliedCredit != '0.00')
              InfoRow(
                'Unapplied credit',
                formatCurrency(preview.unappliedCredit),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: working ? null : onConfirm,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                preview.isPayoff ? 'Confirm Payoff' : 'Confirm Payment',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
