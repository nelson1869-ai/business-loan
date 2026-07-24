import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/offline_sync_service.dart';

/// Diagnostics screen to inspect, retry, or safely purge offline queue items.
///
/// File: `lib/features/dev_tools/pages/offline_queue_inspection_page.dart`
class OfflineQueueInspectionPage extends ConsumerWidget {
  const OfflineQueueInspectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(offlineSyncQueueNotifierProvider);
    final notifier = ref.read(offlineSyncQueueNotifierProvider.notifier);
    final service = ref.read(offlineSyncServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Queue Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Queue',
            onPressed: () => notifier.refreshQueueState(),
          ),
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy Safe Summary',
            onPressed: () => _copyDiagnosticSummary(context, queueState),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCards(context, queueState),
            const SizedBox(height: 16),
            if (queueState.retryableFailedCount > 0)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.replay),
                label: Text(
                  'Retry All Retryable Items (${queueState.retryableFailedCount})',
                ),
                onPressed: () async {
                  for (final item in queueState.items) {
                    if (item.status == QueueItemStatus.retryableFailed) {
                      await service.retryItem(item.transactionUuid);
                    }
                  }
                  await notifier.refreshQueueState();
                },
              ),
            const SizedBox(height: 16),
            const Text(
              'Queued Transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (queueState.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'No queued mutations in local database.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: queueState.items.length,
                separatorBuilder: (_, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = queueState.items[index];
                  return _buildQueueItemCard(context, item, service, notifier);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, OfflineQueueState state) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 2.2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard('Pending', '${state.pendingCount}', Colors.blue),
        _buildStatCard(
          'Retryable Failed',
          '${state.retryableFailedCount}',
          Colors.orange,
        ),
        _buildStatCard(
          'Permanently Failed',
          '${state.permanentlyFailedCount}',
          Colors.red,
        ),
        _buildStatCard('Conflicts', '${state.conflictCount}', Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueItemCard(
    BuildContext context,
    OfflineQueueItemModel item,
    OfflineSyncService service,
    OfflineSyncQueueNotifier notifier,
  ) {
    final statusColor = _statusColor(item.status);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: statusColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(_statusIcon(item.status), color: statusColor, size: 20),
        ),
        title: Text(
          '${item.method} ${item.endpoint}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          'UUID: ${item.transactionUuid.substring(0, 8)}... | Status: ${item.status.name}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Created At: ${item.createdAt.toIso8601String()}'),
                Text('Retry Count: ${item.retryCount}'),
                if (item.lastAttemptAt != null)
                  Text(
                    'Last Attempt: ${item.lastAttemptAt!.toIso8601String()}',
                  ),
                if (item.lastErrorCode != null)
                  Text(
                    'Error Code: ${item.lastErrorCode}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                if (item.lastErrorMessage != null)
                  Text(
                    'Error Details: ${item.lastErrorMessage}',
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text(
                        'Remove',
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: () =>
                          _confirmDelete(context, item, service, notifier),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      onPressed: () async {
                        await service.retryItem(item.transactionUuid);
                        await notifier.refreshQueueState();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(QueueItemStatus status) {
    switch (status) {
      case QueueItemStatus.pending:
      case QueueItemStatus.syncing:
        return Colors.blue;
      case QueueItemStatus.retryableFailed:
        return Colors.orange;
      case QueueItemStatus.permanentlyFailed:
        return Colors.red;
      case QueueItemStatus.conflict:
        return Colors.purple;
    }
  }

  IconData _statusIcon(QueueItemStatus status) {
    switch (status) {
      case QueueItemStatus.pending:
      case QueueItemStatus.syncing:
        return Icons.hourglass_empty;
      case QueueItemStatus.retryableFailed:
        return Icons.warning_amber_rounded;
      case QueueItemStatus.permanentlyFailed:
        return Icons.error_outline;
      case QueueItemStatus.conflict:
        return Icons.merge_type;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    OfflineQueueItemModel item,
    OfflineSyncService service,
    OfflineSyncQueueNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Queue Removal'),
        content: Text(
          'Are you sure you want to delete mutation ${item.transactionUuid.substring(0, 8)}...? '
          'This action will discard the offline change locally.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Delete Permanently',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await service.deleteItem(item.transactionUuid);
      await notifier.refreshQueueState();
    }
  }

  void _copyDiagnosticSummary(BuildContext context, OfflineQueueState state) {
    final summary =
        '''
Lending Nelson Offline Queue Summary:
- Pending Items: ${state.pendingCount}
- Retryable Failures: ${state.retryableFailedCount}
- Permanent Failures: ${state.permanentlyFailedCount}
- Conflicts: ${state.conflictCount}
- Total Items: ${state.totalCount}
''';
    Clipboard.setData(ClipboardData(text: summary));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnostic summary copied to clipboard!')),
    );
  }
}
