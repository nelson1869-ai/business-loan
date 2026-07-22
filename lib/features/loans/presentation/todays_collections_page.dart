import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../dashboard/domain/dashboard_data.dart';
import 'providers/loans_provider.dart';

class TodaysCollectionsPage extends ConsumerWidget {
  const TodaysCollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(todaysCollectionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Collections")),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load collections.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(todaysCollectionsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (collection) {
          final totalDue = double.tryParse(collection.totalDueToday) ?? 0;
          final totalCollected =
              double.tryParse(collection.totalCollectedToday) ?? 0;
          final pct = totalDue > 0
              ? ((totalCollected / totalDue) * 100).clamp(0, 100)
              : 0.0;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(todaysCollectionsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Daily Collection Progress',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 14,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _Stat(
                                label: 'Due Today',
                                value: formatCurrency(collection.totalDueToday),
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Expanded(
                              child: _Stat(
                                label: 'Collected',
                                value: formatCurrency(
                                  collection.totalCollectedToday,
                                ),
                                color: Colors.green,
                              ),
                            ),
                            Expanded(
                              child: _Stat(
                                label: 'Remaining',
                                value: formatCurrency(
                                  (totalDue - totalCollected).toStringAsFixed(
                                    2,
                                  ),
                                ),
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Scheduled Collections (${collection.dueItems.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (collection.dueItems.isEmpty)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'No collections due today.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  ...collection.dueItems.map(
                    (item) => _CollectionTile(item: item),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.item});

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
              formatCurrency(item.amountDue),
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
