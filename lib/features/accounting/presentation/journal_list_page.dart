import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/presentation/design_system/app_state_views.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/online_required_banner.dart';
import '../domain/journal_entry.dart';
import 'accounting_provider.dart';

/// Read-only immutable accounting journal browser.
class JournalListPage extends ConsumerWidget {
  const JournalListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journals = ref.watch(journalsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Accounting Journals')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const OnlineRequiredBanner(),
            Expanded(
              child: journals.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: FilledButton.icon(
                    onPressed: () => ref.invalidate(journalsProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text(ApiErrorMapper.message(error)),
                  ),
                ),
                data: (items) => items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: AppEmptyState(
                            icon: Icons.account_balance_outlined,
                            title: 'No posted journals',
                            description:
                                'Immutable journal entries will appear here after a supported financial transaction is posted.',
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.refresh(journalsProvider.future),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final journal = items[index];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.lock_outline),
                                title: Text(journal.description),
                                subtitle: Text(
                                  '${journal.sourceType} • ${journal.status}\n'
                                  '${journal.postedAt.toLocal()}',
                                ),
                                isThreeLine: true,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _showJournal(context, journal),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showJournal(
    BuildContext context,
    JournalEntry journal,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              journal.description,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Journal ${journal.id}'),
            Text('Source ${journal.sourceType} / ${journal.sourceRecordId}'),
            Text('Reconciliation: ${journal.reconciliationStatus}'),
            const Divider(height: 24),
            ...journal.lines.map(
              (line) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${line.lineNumber}. ${line.memo}'),
                subtitle: Text('Account ${line.accountId}'),
                trailing: Text(
                  line.debit != '0.00'
                      ? 'DR ${formatCurrency(line.debit)}'
                      : 'CR ${formatCurrency(line.credit)}',
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.lock_outline, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Posted journals are read-only and immutable.'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
