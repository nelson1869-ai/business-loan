import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../loans/domain/models/loan.dart';
import '../../loans/domain/models/payment.dart';
import '../../loans/presentation/providers/loans_provider.dart';

class PaymentHistorySection extends ConsumerWidget {
  const PaymentHistorySection({
    super.key,
    required this.borrowerId,
    required this.loansAsync,
    required this.theme,
  });

  final String borrowerId;
  final AsyncValue<List<Loan>> loansAsync;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment History',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        loansAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Could not load payment data',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          data: (loans) {
            if (loans.isEmpty) {
              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No loans or payments recorded yet.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }
            return _BorrowerPaymentsList(loans: loans, theme: theme);
          },
        ),
      ],
    );
  }
}

class _BorrowerPaymentsList extends ConsumerWidget {
  const _BorrowerPaymentsList({required this.loans, required this.theme});

  final List<Loan> loans;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPayments = <_LoanPaymentEntry>[];

    for (final loan in loans) {
      final paymentsAsync = ref.watch(loanPaymentsProvider(loan.id));
      paymentsAsync.whenData((payments) {
        for (final p in payments) {
          allPayments.add(_LoanPaymentEntry(loan: loan, payment: p));
        }
      });
    }

    if (allPayments.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.receipt_long,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No payment transactions recorded yet.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    allPayments.sort(
      (a, b) => b.payment.effectiveDate.compareTo(a.payment.effectiveDate),
    );

    return Column(
      children: allPayments.map((entry) {
        final p = entry.payment;
        final isReversal = p.entryType == 'Reversal';
        final shortLoanId = entry.loan.id.length >= 8
            ? entry.loan.id.substring(0, 8)
            : entry.loan.id;

        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: isReversal
                  ? Colors.orange.withValues(alpha: 0.12)
                  : Colors.green.withValues(alpha: 0.12),
              child: Icon(
                isReversal ? Icons.undo : Icons.payments_outlined,
                size: 14,
                color: isReversal ? Colors.orange : Colors.green,
              ),
            ),
            title: Text(
              isReversal
                  ? 'Reversal · Loan #$shortLoanId'
                  : 'Payment · Loan #$shortLoanId',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              formatDateShort(p.effectiveDate),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            trailing: Text(
              isReversal ? '-\$${p.amount}' : '+\$${p.amount}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isReversal ? Colors.orange : Colors.green.shade700,
              ),
            ),
            onTap: () => context.push('/loans/${entry.loan.id}/payments'),
          ),
        );
      }).toList(),
    );
  }
}

class _LoanPaymentEntry {
  const _LoanPaymentEntry({required this.loan, required this.payment});

  final Loan loan;
  final LoanPayment payment;
}
