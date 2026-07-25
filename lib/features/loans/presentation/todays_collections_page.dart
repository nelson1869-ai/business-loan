import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/design_system/design_system.dart';
import '../../dashboard/domain/dashboard_data.dart';
import 'providers/loans_provider.dart';
import 'providers/collection_task_state_provider.dart';
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
    final completed = ref.watch(completedCollectionTasksProvider);
    final followUps = ref.watch(collectionFollowUpsProvider);

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
                if (collection.dueItems.isNotEmpty) ...[
                  FilledButton.icon(
                    onPressed: () =>
                        _showScheduleDialog(context, collection.dueItems),
                    icon: const Icon(Icons.add_task_outlined),
                    label: const Text('Schedule Follow-up'),
                  ),
                  const SizedBox(height: 14),
                ],
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
                  ...items.map((item) {
                    final key = '${item.loanId}:${item.installmentNumber}';
                    return CollectionTaskCard(
                      item: item,
                      isCompleted:
                          completed.valueOrNull?.contains(key) ?? false,
                      onComplete: () async {
                        await completeCollectionTask(
                          ref,
                          item.loanId,
                          item.installmentNumber,
                        );
                      },
                    );
                  }),
                const SizedBox(height: 16),
                Text(
                  'Scheduled Follow-ups',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                followUps.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) =>
                      Text('Unable to load follow-ups: $error'),
                  data: (tasks) => tasks.isEmpty
                      ? const Text('No scheduled follow-ups')
                      : Column(
                          children: tasks.map((task) {
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.event_note_outlined),
                                title: Text(
                                  '${task.taskType} · ${task.priority}',
                                ),
                                subtitle: Text(
                                  '${task.dueAt.toLocal()}'
                                  '${task.promisedAmount == null ? '' : '\nPromise: ${task.promisedAmount} on ${task.promiseDate?.toLocal().toString().substring(0, 10)} · ${task.promiseStatus}'}'
                                  '${task.description == null ? '' : '\n${task.description}'}',
                                ),
                                trailing: task.status == 'Completed'
                                    ? const AppStatusChip(status: 'Completed')
                                    : IconButton(
                                        tooltip: 'Complete follow-up',
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                        ),
                                        onPressed: () =>
                                            completeScheduledFollowUp(
                                              ref,
                                              task.id,
                                            ),
                                      ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showScheduleDialog(
    BuildContext context,
    List<DashboardDueItem> items,
  ) async {
    var selected = items.first;
    var taskType = 'Call';
    var priority = 'Normal';
    final description = TextEditingController();
    final promisedAmount = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule Follow-up'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<DashboardDueItem>(
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'Borrower / Loan',
                  ),
                  items: items
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.borrowerName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selected = value);
                    }
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: taskType,
                  decoration: const InputDecoration(labelText: 'Task type'),
                  items:
                      const [
                            'Call',
                            'Visit',
                            'Message',
                            'PromiseToPay',
                            'General',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setDialogState(() => taskType = value ?? taskType),
                ),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const ['Low', 'Normal', 'High', 'Critical']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => priority = value ?? priority),
                ),
                TextField(
                  controller: description,
                  maxLength: 2000,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                if (taskType == 'PromiseToPay')
                  TextField(
                    controller: promisedAmount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Promised amount',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
    if (result == true && context.mounted) {
      final promiseValue = double.tryParse(promisedAmount.text.trim());
      if (taskType == 'PromiseToPay' &&
          (promiseValue == null || promiseValue <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid promised amount.')),
        );
        description.dispose();
        promisedAmount.dispose();
        return;
      }
      await createCollectionFollowUp(
        ref,
        item: selected,
        taskType: taskType,
        priority: priority,
        dueAt: DateTime.now().add(const Duration(hours: 1)),
        description: description.text,
        promisedAmount: promisedAmount.text,
        promiseDate: DateTime.now().add(const Duration(days: 7)),
      );
    }
    description.dispose();
    promisedAmount.dispose();
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
