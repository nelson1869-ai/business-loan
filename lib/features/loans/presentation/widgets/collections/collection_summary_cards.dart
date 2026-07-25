import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';
import 'package:lending_nelson/core/utils/formatters.dart';
import 'package:lending_nelson/features/loans/presentation/providers/loans_provider.dart';

/// Responsive grid card displaying Collection Summary Metrics.
class CollectionSummaryCards extends StatelessWidget {
  final TodaysCollectionData collection;

  const CollectionSummaryCards({super.key, required this.collection});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final overdueCount = collection.dueItems.where((i) => i.isOverdue).length;
    final totalDue = double.tryParse(collection.totalDueToday) ?? 0;
    final totalCollected = double.tryParse(collection.totalCollectedToday) ?? 0;
    final remaining = (totalDue - totalCollected).clamp(0, double.infinity);

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: constraints.maxWidth > 600 ? 2.2 : 1.8,
          children: [
            AppMetricCard(
              label: "Today's Visits",
              value: '${collection.dueItems.length} Visits',
              icon: Icons.directions_walk_outlined,
              color: theme.colorScheme.primary,
            ),
            AppMetricCard(
              label: 'Promise To Pay',
              value: '2 Due',
              icon: Icons.handshake_outlined,
              color: Colors.teal,
            ),
            AppMetricCard(
              label: 'Overdue Tasks',
              value: '$overdueCount Overdue',
              icon: Icons.warning_amber_outlined,
              color: overdueCount > 0 ? Colors.red : Colors.green,
            ),
            AppMetricCard(
              label: 'Remaining Due',
              value: formatCurrency(remaining.toStringAsFixed(2)),
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.orange.shade800,
            ),
          ],
        );
      },
    );
  }
}
