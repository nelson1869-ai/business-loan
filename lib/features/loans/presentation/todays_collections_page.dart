import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/design_system/design_system.dart';
import '../../dashboard/domain/dashboard_data.dart';
import 'providers/loans_provider.dart';
import 'widgets/collections/collection_filter_bar.dart';
import 'widgets/collections/collection_header_card.dart';
import 'widgets/collections/collection_summary_cards.dart';
import 'widgets/collections/collection_task_card.dart';

/// Modernized Material 3 Collection Tasks & Follow-ups Daily Workspace.
class TodaysCollectionsPage extends ConsumerStatefulWidget {
  const TodaysCollectionsPage({super.key});

  @override
  ConsumerState<TodaysCollectionsPage> createState() =>
      _TodaysCollectionsPageState();
}

class _TodaysCollectionsPageState extends ConsumerState<TodaysCollectionsPage> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(todaysCollectionsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Collection Tasks & Follow-ups'),
      ),
      body: data.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            AppCardSkeleton(),
            SizedBox(height: 12),
            AppCardSkeleton(),
            SizedBox(height: 12),
            AppCardSkeleton(),
          ],
        ),
        error: (Object e, _) => Center(
          child: AppErrorState(
            error: e.toString(),
            onRetry: () => ref.invalidate(todaysCollectionsProvider),
          ),
        ),
        data: (collection) {
          final items = _filterItems(collection.dueItems);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(todaysCollectionsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Officer Greeting & Header Card
                CollectionHeaderCard(collection: collection),
                const SizedBox(height: 14),
                // 2. Summary Metric Cards
                CollectionSummaryCards(collection: collection),
                const SizedBox(height: 16),
                // 3. Multi-State Filter Chips Bar
                CollectionFilterBar(
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (val) {
                    setState(() => _selectedFilter = val);
                  },
                ),
                const SizedBox(height: 14),
                // 4. Task List Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Tasks (${items.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Sorted by Due Time',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 5. Expandable Task List or Empty State
                if (items.isEmpty)
                  AppEmptyState(
                    icon: Icons.task_alt_outlined,
                    title: 'No Tasks Match Filter',
                    description:
                        'You have no scheduled collection tasks matching standard criteria.',
                    actionLabel: 'Reset Filter',
                    onAction: () {
                      setState(() => _selectedFilter = 'All');
                    },
                  )
                else
                  ...items.map((item) => CollectionTaskCard(item: item)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<DashboardDueItem> _filterItems(List<DashboardDueItem> original) {
    switch (_selectedFilter) {
      case 'Overdue':
        return original.where((i) => i.isOverdue).toList();
      case 'Today':
        return original.where((i) => !i.isOverdue).toList();
      default:
        return original;
    }
  }
}
