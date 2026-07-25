import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../../loans/domain/models/loan.dart';
import '../../domain/borrower_model.dart';

/// Loans Tab View showing categorized loan cards and polished empty states.
class LoansTabView extends StatelessWidget {
  final Borrower borrower;
  final List<Loan> loans;

  const LoansTabView({super.key, required this.borrower, required this.loans});

  @override
  Widget build(BuildContext context) {
    if (loans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_outlined,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No Loans Recorded',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'This borrower has no active or past loans in the system.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.push(
                  '/borrowers/${borrower.id}/loans/new',
                  extra: borrower,
                ),
                icon: const Icon(Icons.add_card, size: 18),
                label: const Text('Issue New Loan'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        final orig = double.tryParse(loan.originalPrincipal) ?? 0;
        final out = double.tryParse(loan.outstandingPrincipal) ?? 0;
        final ratePct = (double.tryParse(loan.monthlyRate) ?? 0) * 100;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Loan #${loan.id.length >= 8 ? loan.id.substring(0, 8) : loan.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _StatusChip(status: loan.status),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _LoanInfo(
                        label: 'Principal',
                        value: formatCurrency(orig.toStringAsFixed(2)),
                      ),
                    ),
                    Expanded(
                      child: _LoanInfo(
                        label: 'Balance',
                        value: formatCurrency(out.toStringAsFixed(2)),
                        isHighlight: true,
                      ),
                    ),
                    Expanded(
                      child: _LoanInfo(
                        label: 'Rate',
                        value: '${ratePct.toStringAsFixed(1)}%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _LoanInfo(
                        label: 'Start Date',
                        value: loan.startDate.length >= 10
                            ? loan.startDate.substring(0, 10)
                            : loan.startDate,
                      ),
                    ),
                    Expanded(
                      child: _LoanInfo(
                        label: 'Final Due',
                        value: loan.finalDueDate.length >= 10
                            ? loan.finalDueDate.substring(0, 10)
                            : loan.finalDueDate,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          context.push('/loans/${loan.id}', extra: loan),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text(
                        'Details',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoanInfo extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _LoanInfo({
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
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: isHighlight ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green;
        break;
      case 'overdue':
        color = colors.error;
        break;
      case 'closed':
      case 'paid':
        color = colors.primary;
        break;
      default:
        color = colors.outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
