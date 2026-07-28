import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../../../loans/domain/models/loan.dart';
import '../../../loans/domain/models/payment.dart';
import '../../../loans/presentation/providers/loans_provider.dart';

/// Payments Tab View featuring a modern timeline of payment transactions.
class PaymentsTabView extends ConsumerWidget {
  final List<Loan> loans;

  const PaymentsTabView({super.key, required this.loans});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Use immutable ledger entries rather than scheduled installments. The
    // ledger owns the actual amount and financial/effective date.
    final timelineItems = <_TimelineItemData>[];
    var loading = false;
    for (final loan in loans) {
      final ledger = ref.watch(loanPaymentsProvider(loan.id));
      if (ledger.isLoading) loading = true;
      for (final LoanPayment payment
          in ledger.valueOrNull ?? const <LoanPayment>[]) {
        if (payment.entryType == 'Payment') {
          timelineItems.add(
            _TimelineItemData(
              loanId: loan.id,
              date: payment.effectiveDate,
              amount: payment.amount,
              method: 'Cash / Bank Transfer',
              collector: 'Recorded by system',
              receiptNo:
                  'RCP-${payment.id.length >= 6 ? payment.id.substring(0, 6) : payment.id}',
            ),
          );
        }
      }
    }
    timelineItems.sort((a, b) => b.date.compareTo(a.date));

    if (timelineItems.isEmpty) {
      if (loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_outlined,
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
                  'No recorded payment transactions found for this borrower.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: timelineItems.length,
      itemBuilder: (context, index) {
        final item = timelineItems[index];
        final isLast = index == timelineItems.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline Indicator Column
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
                    height: 60,
                    color: theme.colorScheme.outlineVariant,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Payment Receipt Details Card
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
                            formatCurrency(item.amount),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            item.date,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Receipt: ${item.receiptNo}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Method: ${item.method}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Officer: ${item.collector}',
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

class _TimelineItemData {
  final String loanId;
  final String date;
  final String amount;
  final String method;
  final String collector;
  final String receiptNo;

  const _TimelineItemData({
    required this.loanId,
    required this.date,
    required this.amount,
    required this.method,
    required this.collector,
    required this.receiptNo,
  });
}
