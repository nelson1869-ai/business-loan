import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';
import 'package:lending_nelson/core/utils/formatters.dart';
import 'package:lending_nelson/features/dashboard/domain/dashboard_data.dart';

/// Task Detail Bottom Sheet displaying Borrower summary, notes, activity timeline, and quick actions.
class CollectionTaskDetailSheet extends StatelessWidget {
  final DashboardDueItem item;

  const CollectionTaskDetailSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, DashboardDueItem item) {
    return AppBottomSheet.show(
      context,
      title: 'Task Details — ${item.borrowerName}',
      child: CollectionTaskDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: item.isOverdue
                  ? Colors.red.withValues(alpha: 0.15)
                  : colorScheme.primaryContainer,
              child: Text(
                item.borrowerName.isNotEmpty
                    ? item.borrowerName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: item.isOverdue
                      ? Colors.red
                      : colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            title: Text(
              item.borrowerName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Loan ID: ${item.loanId} · Installment #${item.installmentNumber}',
            ),
            trailing: AppStatusChip(
              status: item.isOverdue ? 'Overdue' : 'Pending',
            ),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DetailStat(
                label: 'Amount Due Today',
                value: formatCurrency(item.amountDue),
                color: item.isOverdue ? Colors.red : colorScheme.primary,
              ),
              _DetailStat(
                label: 'Task Type',
                value: 'Collection Visit',
                color: Colors.teal,
              ),
              _DetailStat(
                label: 'Priority',
                value: item.isOverdue ? 'High Priority' : 'Normal',
                color: item.isOverdue ? Colors.red : Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'Officer Notes & Promise History',
            icon: Icons.note_alt_outlined,
            children: [
              Text(
                'Previous Visit: Customer requested morning visit after 9:00 AM.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Promise Date: Pay full installment on or before Friday.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'Activity Timeline',
            icon: Icons.timeline_outlined,
            children: [
              _TimelineStep(
                title: 'Task Created',
                subtitle: 'Scheduled for Today 9:00 AM',
                isDone: true,
              ),
              _TimelineStep(
                title: 'SMS Reminder Sent',
                subtitle: 'Sent at 8:15 AM',
                isDone: true,
              ),
              _TimelineStep(
                title: 'Field Visit',
                subtitle: 'In Progress',
                isDone: false,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/loans/${item.loanId}/payments');
                  },
                  icon: const Icon(Icons.point_of_sale, size: 16),
                  label: const Text('Collect Payment'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task marked completed')),
                  );
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Complete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailStat({
    required this.label,
    required this.value,
    required this.color,
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
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDone;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isDone ? Colors.green : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
