import 'package:flutter/material.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../domain/models/loan.dart';

/// Schedule Tab View displaying modern installment timeline with expansion breakdown.
class LoanScheduleTab extends StatelessWidget {
  final Loan loan;
  final VoidCallback? onRecordPayment;

  const LoanScheduleTab({super.key, required this.loan, this.onRecordPayment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final installments = loan.installments;

    if (installments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Schedule Items Found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No installment schedule returned for this loan.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: installments.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Installment Schedule',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        final inst = installments[index - 1];
        final isPaid = inst.status == 'Paid';
        final isOverdue = inst.status == 'Overdue';
        final canPay = loan.status == 'Active' || loan.status == 'Overdue';

        final expected = double.tryParse(inst.expectedPayment) ?? 0;
        final paid = double.tryParse(inst.paidAmount) ?? 0;
        final remaining = expected > paid ? expected - paid : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            title: Text(
              'Payment ${inst.installmentNumber} · ${formatCurrency(inst.expectedPayment)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              '${formatDateShort(inst.dueDate)} · ${inst.status}',
              style: TextStyle(
                fontSize: 12,
                color: isOverdue
                    ? Colors.red
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: _StatusBadge(status: inst.status),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 16),
              _DetailRow(
                label: 'Principal',
                value: formatCurrency(inst.expectedPrincipal),
              ),
              _DetailRow(
                label: 'Interest',
                value: formatCurrency(inst.expectedInterest),
              ),
              _DetailRow(
                label: 'Remaining principal',
                value: formatCurrency(inst.expectedRemainingPrincipal),
              ),
              _DetailRow(
                label: 'Paid Amount',
                value: formatCurrency(inst.paidAmount),
              ),
              _DetailRow(
                label: 'Remaining Amount Due',
                value: formatCurrency(remaining.toStringAsFixed(2)),
                isHighlight: true,
              ),
              if (!isPaid && canPay && onRecordPayment != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onRecordPayment,
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: Text('Record Payment for #${inst.installmentNumber}'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

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
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Color color;
    switch (status.toLowerCase()) {
      case 'paid':
        color = Colors.green;
        break;
      case 'overdue':
        color = colors.error;
        break;
      case 'partial':
        color = Colors.orange;
        break;
      default:
        color = colors.primary;
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
