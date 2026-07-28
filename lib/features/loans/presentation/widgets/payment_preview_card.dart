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
            Text('Payment preview', style: theme.textTheme.titleLarge),
            InfoRow('Payment', formatCurrency(preview.paymentAmount)),
            InfoRow(
              'Total interest owed',
              formatCurrency(preview.totalInterestBefore),
            ),
            InfoRow('Interest paid', formatCurrency(preview.appliedInterest)),
            InfoRow('Principal paid', formatCurrency(preview.appliedPrincipal)),
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
              InfoRow(
                'Days late',
                '${preview.overdueDays} (${formatCurrency(((double.tryParse(preview.accruedInterest) ?? 0.0) / (preview.overdueDays > 0 ? preview.overdueDays : 1)).toStringAsFixed(2))}/day)',
              ),
            if (preview.daysEarly > 0)
              InfoRow('Days early', '${preview.daysEarly}'),
            InfoRow(
              'Total balance remaining',
              formatCurrency(
                ((double.tryParse(preview.interestAfter) ?? 0.0) +
                        (double.tryParse(preview.principalAfter) ?? 0.0))
                    .toStringAsFixed(2),
              ),
            ),
            if (preview.unappliedCredit != '0.00') ...[
              InfoRow(
                'Unapplied credit',
                formatCurrency(preview.unappliedCredit),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Overpayment of ${formatCurrency(preview.unappliedCredit)} detected! Issue cash refund to borrower or hold as credit.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
