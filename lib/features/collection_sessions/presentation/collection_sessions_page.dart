import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/security/officer_session.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/online_required_banner.dart';
import '../data/collection_session_repository.dart';
import '../domain/collection_session.dart';
import 'collection_session_provider.dart';

/// Backend-authoritative cash collection and reconciliation workflow.
class CollectionSessionsPage extends ConsumerWidget {
  const CollectionSessionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(officerSessionProvider).valueOrNull;
    final sessions = ref.watch(collectionSessionsProvider);
    final online = ref.watch(backendOnlineProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Sessions'),
        actions: [
          if (session?.can('reconciliation.submit') == true)
            IconButton(
              tooltip: 'Open collection session',
              onPressed: online && session != null
                  ? () => _open(context, ref, session)
                  : null,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: Column(
        children: [
          const OnlineRequiredBanner(),
          Expanded(
            child: sessions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: FilledButton.icon(
                  onPressed: () => ref.invalidate(collectionSessionsProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text(ApiErrorMapper.message(error)),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No collection sessions.'))
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(collectionSessionsProvider.future),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Card(
                            child: ListTile(
                              title: Text(
                                'Session ${item.id.substring(0, 8)} • ${item.status}',
                              ),
                              subtitle: Text(
                                'Expected ${formatCurrency(item.expectedCash)} • '
                                'Actual ${formatCurrency(item.actualCash)}\n'
                                'Variance ${formatCurrency(item.cashVariance)}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () =>
                                  _details(context, ref, item, session),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    OfficerSession session,
  ) async {
    final opening = await _prompt(context, 'Opening cash', 'Amount');
    if (opening == null || opening.isEmpty || !context.mounted) return;
    await _run(context, ref, () {
      return ref
          .read(collectionSessionRepositoryProvider)
          .open(collectorUserId: session.userId, openingCash: opening);
    });
  }

  Future<void> _details(
    BuildContext context,
    WidgetRef ref,
    CollectionSession item,
    OfficerSession? officer,
  ) async {
    final ownSession = officer?.userId == item.collectorUserId;
    final canSubmit = officer?.can('reconciliation.submit') == true;
    final canApprove = officer?.can('reconciliation.approve') == true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Collection Session',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _value('Status', item.status),
                _value('Opening cash', formatCurrency(item.openingCash)),
                _value('Expected cash', formatCurrency(item.expectedCash)),
                _value('Actual cash', formatCurrency(item.actualCash)),
                _value('Variance', formatCurrency(item.cashVariance)),
                _value('Deposit', formatCurrency(item.depositAmount)),
                if (item.varianceReason != null)
                  _value('Variance reason', item.varianceReason!),
                if (item.depositReference != null)
                  _value('Deposit reference', item.depositReference!),
                const SizedBox(height: 16),
                if (ownSession &&
                    canSubmit &&
                    {'open', 'collecting'}.contains(item.status))
                  FilledButton(
                    onPressed: () => _submit(sheetContext, ref, item),
                    child: const Text('Submit Session'),
                  ),
                if (!ownSession && canApprove && item.status == 'submitted')
                  FilledButton(
                    onPressed: () =>
                        _reasonAction(sheetContext, ref, item, 'review'),
                    child: const Text('Review Session'),
                  ),
                if (canApprove && item.status == 'reviewed')
                  FilledButton(
                    onPressed: () =>
                        _reasonAction(sheetContext, ref, item, 'reconcile'),
                    child: const Text('Reconcile Session'),
                  ),
                if (canApprove && item.status == 'reconciled')
                  FilledButton(
                    onPressed: () => _deposit(sheetContext, ref, item),
                    child: const Text('Record Deposit'),
                  ),
                if (canApprove && item.status == 'deposited')
                  FilledButton(
                    onPressed: () =>
                        _reasonAction(sheetContext, ref, item, 'close'),
                    child: const Text('Close Session'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _value(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    CollectionSession item,
  ) async {
    final actual = await _prompt(context, 'Submit session', 'Actual cash');
    if (actual == null || !context.mounted) return;
    final reason = await _prompt(
      context,
      'Variance explanation',
      'Reason when cash differs',
      required: false,
    );
    if (!context.mounted) return;
    Navigator.pop(context);
    await _run(context, ref, () {
      return ref
          .read(collectionSessionRepositoryProvider)
          .submit(
            id: item.id,
            actualCash: actual,
            varianceReason: reason?.trim().isEmpty == true ? null : reason,
          );
    });
  }

  Future<void> _reasonAction(
    BuildContext context,
    WidgetRef ref,
    CollectionSession item,
    String action,
  ) async {
    final reason = await _prompt(
      context,
      '${action[0].toUpperCase()}${action.substring(1)} session',
      'Reason',
    );
    if (reason == null || reason.trim().length < 3 || !context.mounted) return;
    Navigator.pop(context);
    final repository = ref.read(collectionSessionRepositoryProvider);
    await _run(
      context,
      ref,
      () => switch (action) {
        'review' => repository.review(item.id, reason.trim()),
        'reconcile' => repository.reconcile(item.id, reason.trim()),
        _ => repository.close(item.id, reason.trim()),
      },
    );
  }

  Future<void> _deposit(
    BuildContext context,
    WidgetRef ref,
    CollectionSession item,
  ) async {
    final reference = await _prompt(
      context,
      'Record deposit',
      'Deposit reference',
    );
    if (reference == null || reference.trim().isEmpty || !context.mounted) {
      return;
    }
    Navigator.pop(context);
    await _run(context, ref, () {
      return ref
          .read(collectionSessionRepositoryProvider)
          .deposit(
            id: item.id,
            amount: item.actualCash,
            reference: reference.trim(),
          );
    });
  }

  Future<String?> _prompt(
    BuildContext context,
    String title,
    String label, {
    bool required = true,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!required || controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<CollectionSession> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(collectionSessionsProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ApiErrorMapper.message(error))));
    }
  }
}
