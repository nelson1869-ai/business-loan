import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../domain/models/loan.dart';
import '../../providers/loans_provider.dart';

/// Payments Tab View showing timeline of recorded payment transactions.
class LoanPaymentsTab extends ConsumerWidget {
  final Loan loan;

  const LoanPaymentsTab({super.key, required this.loan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final payments = <_PaymentRecord>[];

    final ledger = ref.watch(loanPaymentsProvider(loan.id)).valueOrNull;
    if (ledger == null) {
      return const Center(child: CircularProgressIndicator());
    }
    for (final payment in ledger) {
      if (payment.entryType == 'Payment') {
        payments.add(
          _PaymentRecord(
            receiptNo:
                'RCP-${payment.id.length >= 6 ? payment.id.substring(0, 6) : payment.id}',
            date: formatDateShort(payment.effectiveDate),
            amount: payment.amount,
            collector: 'Recorded by system',
            method: 'Cash / Mobile Transfer',
            refNo:
                'REF-${payment.requestId.length >= 8 ? payment.requestId.substring(0, 8) : payment.requestId}',
          ),
        );
      }
    }

    if (payments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No Payment Receipts',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No payments recorded yet for this loan.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final payment = payments[index];
        final isLast = index == payments.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Colors.green,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 55,
                    color: theme.colorScheme.outlineVariant,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Text(
                            formatCurrency(payment.amount),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            payment.date,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Receipt: ${payment.receiptNo} · Ref: ${payment.refNo}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          Text(
                            'Method: ${payment.method}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Officer: ${payment.collector}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PaymentRecord {
  final String receiptNo;
  final String date;
  final String amount;
  final String collector;
  final String method;
  final String refNo;

  const _PaymentRecord({
    required this.receiptNo,
    required this.date,
    required this.amount,
    required this.collector,
    required this.method,
    required this.refNo,
  });
}
