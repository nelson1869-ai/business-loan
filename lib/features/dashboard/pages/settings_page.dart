import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/offline_sync_service.dart';
import '../../auth/data/auth_repository.dart';

/// Settings screen for officer profile, data synchronization, audit logs, and authentication.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineSyncService = ref.watch(offlineSyncServiceProvider);
    final pendingCountAsync = ref.watch(offlineSyncPendingCountProvider);
    final pendingCount = pendingCountAsync.asData?.value ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.badge_outlined),
                    title: Text('Officer Profile'),
                    subtitle: Text('ID: officer-999 | Role: Loan Officer'),
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).dividerTheme.color,
                  ),
                  const ListTile(
                    leading: Icon(Icons.apartment_outlined),
                    title: Text('Assigned Branch'),
                    subtitle: Text('Nairobi Central (ID: branch-001)'),
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).dividerTheme.color,
                  ),
                  ListTile(
                    leading: Badge.count(
                      count: pendingCount,
                      isLabelVisible: pendingCount > 0,
                      child: const Icon(Icons.sync_outlined),
                    ),
                    title: const Text('Sync Offline Data'),
                    subtitle: Text(
                      pendingCount > 0
                          ? '$pendingCount item${pendingCount > 1 ? 's' : ''} waiting to sync'
                          : 'All local data is fully synced with server',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final countBefore = await offlineSyncService
                          .getPendingCount();
                      if (countBefore == 0) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No pending offline items. All data is up to date!',
                            ),
                          ),
                        );
                        return;
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Syncing $countBefore offline item${countBefore > 1 ? 's' : ''}...',
                          ),
                        ),
                      );
                      await offlineSyncService.drainQueue();
                      ref.invalidate(offlineSyncPendingCountProvider);
                      final countAfter = await offlineSyncService
                          .getPendingCount();
                      final syncedCount = countBefore - countAfter;
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            syncedCount > 0
                                ? 'Successfully synced $syncedCount item${syncedCount > 1 ? 's' : ''} to server!'
                                : 'Server unreachable. Will retry automatically when online.',
                          ),
                        ),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).dividerTheme.color,
                  ),
                  ListTile(
                    leading: const Icon(Icons.history_outlined),
                    title: const Text('View Audit Logs'),
                    subtitle: const Text('Local security and mutation logs'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (ctx) => SafeArea(
                          child: DraggableScrollableSheet(
                            expand: false,
                            initialChildSize: 0.6,
                            minChildSize: 0.4,
                            maxChildSize: 0.9,
                            builder: (context, scrollController) => Column(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'Local Audit Logs',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Consumer(
                                    builder: (context, ref, child) {
                                      final dbService = ref.watch(
                                        databaseServiceProvider,
                                      );
                                      return FutureBuilder<
                                        List<Map<String, dynamic>>
                                      >(
                                        future: dbService.database.then(
                                          (db) => db.query(
                                            'audit_logs',
                                            orderBy: 'timestamp DESC',
                                            limit: 50,
                                          ),
                                        ),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                          final logs =
                                              snapshot.data ?? const [];
                                          if (logs.isEmpty) {
                                            return const Center(
                                              child: Text(
                                                'No audit logs recorded yet.',
                                              ),
                                            );
                                          }
                                          return ListView.builder(
                                            controller: scrollController,
                                            itemCount: logs.length,
                                            itemBuilder: (context, index) {
                                              final item = logs[index];
                                              final action =
                                                  item['action'] as String? ??
                                                  'MUTATION';
                                              final time =
                                                  item['timestamp']
                                                      as String? ??
                                                  '';
                                              final entityId =
                                                  item['entity_id']
                                                      as String? ??
                                                  '';
                                              return ListTile(
                                                leading: const Icon(
                                                  Icons.shield_outlined,
                                                ),
                                                title: Text(action),
                                                subtitle: Text(
                                                  'ID: $entityId\nAt: $time',
                                                ),
                                                isThreeLine: true,
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).dividerTheme.color,
                  ),
                  ListTile(
                    leading: const Icon(Icons.developer_mode_outlined),
                    title: const Text('Dev Tools'),
                    subtitle: const Text('Reset or seed development data'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/dev-tools'),
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).dividerTheme.color,
                  ),
                  const ListTile(
                    leading: Icon(Icons.phone_android_outlined),
                    title: Text('App Version'),
                    subtitle: Text('1.0.0 (Build 1)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await ref.read(authRepositoryProvider).logout();
                if (!context.mounted) return;
                context.go('/login');
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
