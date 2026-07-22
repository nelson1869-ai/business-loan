import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/dashboard_data.dart';

class TodaysCollectionsSection extends StatelessWidget {
  const TodaysCollectionsSection({super.key, required this.items});

  final List<DashboardDueItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            "Today's Collections",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No collections due today',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          )
        else
          ...items.map((item) => _DueTile(item: item)),
      ],
    );
  }
}

class _DueTile extends StatelessWidget {
  const _DueTile({required this.item});

  final DashboardDueItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/loans/${item.loanId}/payments'),
        leading: CircleAvatar(
          backgroundColor: item.isOverdue
              ? Colors.red.withValues(alpha: 0.1)
              : theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Text(
            item.borrowerName.isNotEmpty
                ? item.borrowerName[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: item.isOverdue ? Colors.red : theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          item.borrowerName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Installment ${item.installmentNumber}',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${item.amountDue}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: item.isOverdue ? Colors.red : null,
              ),
            ),
            if (item.isOverdue)
              Text(
                'Overdue',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
