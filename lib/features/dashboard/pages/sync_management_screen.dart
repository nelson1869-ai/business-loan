import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/offline_sync_service.dart';
import '../../../core/network/server_health_service.dart';

class SyncManagementScreen extends ConsumerWidget {
  const SyncManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(offlineSyncQueueNotifierProvider);
    final serverStatus = ref.watch(serverStatusNotifierProvider);
    final syncService = ref.watch(offlineSyncServiceProvider);

    final isOnline = serverStatus == ServerStatus.serverReady;
    final lastSynced = queueState.lastSyncedAt != null
        ? queueState.lastSyncedAt!.toLocal().toString().split('.').first
        : 'Never';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync & Storage Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(serverStatusNotifierProvider.notifier).refreshStatus();
              ref
                  .read(offlineSyncQueueNotifierProvider.notifier)
                  .refreshQueueState();
            },
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isOnline ? Icons.wifi : Icons.wifi_off,
                    size: 36,
                    color: isOnline ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnline
                              ? 'Backend Server Connected'
                              : 'Working Offline (Saved on Device)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last Synced: $lastSynced',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await syncService.drainQueue();
                      await ref
                          .read(offlineSyncQueueNotifierProvider.notifier)
                          .refreshQueueState();
                    },
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Sync Now'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Summary Stats Row
          Row(
            children: [
              _buildStatCard(
                'Pending',
                '${queueState.pendingCount}',
                Colors.amber.shade800,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'Failures',
                '${queueState.permanentlyFailedCount + queueState.retryableFailedCount}',
                Colors.red.shade700,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'Conflicts',
                '${queueState.conflictCount}',
                Colors.orange.shade800,
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            'Offline Sync Queue (${queueState.items.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (queueState.items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No pending offline operations. All records are synced.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            ...queueState.items.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(
                      item.status,
                    ).withValues(alpha: 0.2),
                    child: Icon(
                      _statusIcon(item.status),
                      color: _statusColor(item.status),
                    ),
                  ),
                  title: Text(
                    '${item.method} ${item.endpoint}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entity: ${item.entityType} | ID: ${item.entityLocalId ?? "N/A"}',
                      ),
                      Text(
                        'Status: ${item.status.name} (Retries: ${item.retryCount})',
                        style: TextStyle(color: _statusColor(item.status)),
                      ),
                      if (item.lastErrorMessage != null)
                        Text(
                          'Error: ${item.lastErrorMessage}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val == 'retry') {
                        await syncService.retryItem(item.transactionUuid);
                      } else if (val == 'delete') {
                        await syncService.deleteItem(item.transactionUuid);
                      }
                      ref
                          .read(offlineSyncQueueNotifierProvider.notifier)
                          .refreshQueueState();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'retry',
                        child: Text('Retry Now'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Remove Item'),
                      ),
                    ],
                  ),
                ),
              );
            }),

          if (queueState.conflicts.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Unresolved Conflicts (${queueState.conflicts.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            ...queueState.conflicts.map((conflict) {
              return Card(
                color: Colors.orange.shade50,
                child: ListTile(
                  title: Text(
                    'Conflict in ${conflict.entityType} #${conflict.localId}',
                  ),
                  subtitle: Text('Detected: ${conflict.detectedAt.toLocal()}'),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color) {
    return Expanded(
      child: Card(
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(title, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(QueueItemStatus status) {
    switch (status) {
      case QueueItemStatus.pending:
        return Colors.amber.shade800;
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
        return Icons.pending_actions;
      case QueueItemStatus.syncing:
        return Icons.sync;
      case QueueItemStatus.retryableFailed:
        return Icons.refresh;
      case QueueItemStatus.permanentlyFailed:
        return Icons.error;
      case QueueItemStatus.conflict:
        return Icons.warning;
    }
  }
}
