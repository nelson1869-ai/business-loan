import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';
import 'package:lending_nelson/features/loans/presentation/providers/loans_provider.dart';
import 'package:lending_nelson/features/loans/presentation/providers/collection_task_state_provider.dart';

/// Header card displaying Officer Greeting, Branch, Date, Task Counts & Sync Status.
class CollectionHeaderCard extends StatelessWidget {
  final TodaysCollectionData collection;
  final List<CollectionFollowUp> followUps;

  const CollectionHeaderCard({
    super.key,
    required this.collection,
    required this.followUps,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalDue = double.tryParse(collection.totalDueToday) ?? 0;
    final totalCollected = double.tryParse(collection.totalCollectedToday) ?? 0;
    final pct = totalDue > 0
        ? ((totalCollected / totalDue) * 100).clamp(0, 100)
        : 0.0;

    final current = DateTime.now();
    final pendingFollowUps = followUps
        .where((task) => task.status == 'Pending')
        .toList(growable: false);
    final overdueCount =
        collection.dueItems.where((item) => item.isOverdue).length +
        pendingFollowUps.where((task) => task.dueAt.isBefore(current)).length;
    final pendingCount = collection.dueItems.length + pendingFollowUps.length;
    final completedCount = followUps
        .where((task) => task.status == 'Completed')
        .length;
    final totalTaskCount = collection.dueItems.length + followUps.length;

    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.assignment_ind_outlined,
                  color: colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, Business Owner',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Branch: Central Office · Today Tasks',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const AppStatusChip(status: 'Synced'),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today Collection Goal Progress',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HeaderStat(
                label: 'Total Tasks',
                value: '$totalTaskCount',
                color: colorScheme.primary,
              ),
              _HeaderStat(
                label: 'Pending',
                value: '$pendingCount',
                color: Colors.blue,
              ),
              _HeaderStat(
                label: 'Overdue',
                value: '$overdueCount',
                color: overdueCount > 0 ? Colors.red : Colors.green,
              ),
              _HeaderStat(
                label: 'Completed',
                value: '$completedCount',
                color: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeaderStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
