import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/offline_sync_service.dart';
import '../../../core/network/server_health_service.dart';
import '../../../core/presentation/design_system/design_system.dart';
import '../../auth/data/auth_repository.dart';
import '../widgets/settings/business_loan_config_sheet.dart';
import '../widgets/settings/roles_permissions_sheet.dart';
import '../widgets/settings/security_backup_sheet.dart';
import '../widgets/settings/user_management_sheet.dart';

/// Modernized Settings & Enterprise Administration Hub.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final offlineSyncService = ref.watch(offlineSyncServiceProvider);
    final queueState = ref.watch(offlineSyncQueueNotifierProvider);
    final forcedOffline = ref.watch(forcedOfflineModeProvider);
    final retryableCount = queueState.items
        .where(
          (item) =>
              item.status == QueueItemStatus.pending ||
              item.status == QueueItemStatus.retryableFailed,
        )
        .length;
    final attentionCount = queueState.items
        .where(
          (item) =>
              item.status == QueueItemStatus.permanentlyFailed ||
              item.status == QueueItemStatus.conflict,
        )
        .length;
    final unresolvedCount = retryableCount + attentionCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Administration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Search Bar
            AppSearchBar(
              controller: _searchCtrl,
              hintText: 'Search settings, users, permissions, sync...',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 16),

            // 2. Profile Card
            if (_query.isEmpty ||
                'account profile officer'.contains(_query.toLowerCase()))
              AppCard(
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: 0.15,
                      ),
                      child: Icon(
                        Icons.person,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Authenticated Account',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Profile details are provided by authentication',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const AppStatusChip(status: 'Signed In'),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Profile editing unavailable',
                      onPressed: null,
                    ),
                  ],
                ),
              ),

            // 3. Users & Access Management Section
            if (_query.isEmpty ||
                'users access roles permissions staff branch'.contains(
                  _query.toLowerCase(),
                ))
              AppSectionCard(
                title: 'Users & Access Control',
                icon: Icons.admin_panel_settings_outlined,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.people_outline),
                    title: const Text('User Management'),
                    subtitle: const Text(
                      'Persistent staff accounts and enforced system roles',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const UserManagementSheet(),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Roles & Permission Matrix'),
                    subtitle: const Text(
                      'View the roles currently enforced by the backend',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const RolesPermissionsSheet(),
                      );
                    },
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // 4. Business & Lending Settings
            if (_query.isEmpty ||
                'business loan lending currency rates receipt'.contains(
                  _query.toLowerCase(),
                ))
              AppSectionCard(
                title: 'Business Presentation Settings',
                icon: Icons.storefront_outlined,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tune_outlined),
                    title: const Text('Business Profile'),
                    subtitle: const Text(
                      'Company name, ISO currency code, and receipt footer',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const BusinessLoanConfigSheet(),
                      );
                    },
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // 5. Offline & Synchronization
            if (_query.isEmpty ||
                'offline sync network status queued pending'.contains(
                  _query.toLowerCase(),
                ))
              AppSectionCard(
                title: 'Offline & Synchronization',
                icon: Icons.cloud_sync_outlined,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.cloud_off_outlined),
                    title: const Text('Force Offline Mode'),
                    subtitle: Text(
                      forcedOffline
                          ? 'Offline testing active; sync queue paused'
                          : 'Normal online operation',
                    ),
                    value: forcedOffline,
                    onChanged: (value) async {
                      ref.read(forcedOfflineModeProvider.notifier).state =
                          value;
                      await ref
                          .read(serverStatusNotifierProvider.notifier)
                          .refreshStatus();
                      if (!value) {
                        await ref.read(offlineSyncServiceProvider).drainQueue();
                        ref.invalidate(offlineSyncPendingCountProvider);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Badge.count(
                      count: unresolvedCount,
                      isLabelVisible: unresolvedCount > 0,
                      child: const Icon(Icons.sync_outlined),
                    ),
                    title: const Text('Sync Offline Data'),
                    subtitle: Text(
                      attentionCount > 0
                          ? '$attentionCount failed item${attentionCount == 1 ? '' : 's'} need attention'
                          : retryableCount > 0
                          ? '$retryableCount item${retryableCount == 1 ? '' : 's'} waiting to sync'
                          : 'All local data is fully synced with server',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: forcedOffline
                        ? null
                        : () async {
                            final actionableItems = queueState.items
                                .where(
                                  (i) =>
                                      i.status == QueueItemStatus.pending ||
                                      i.status == QueueItemStatus.retryableFailed,
                                )
                                .toList();
                            final countBefore = actionableItems.length;
                            if (countBefore == 0) {
                              if (!context.mounted) return;
                              if (attentionCount > 0) {
                                context.push('/sync-management');
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No pending offline items. Data is up to date.',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Syncing $countBefore offline items...',
                                ),
                              ),
                            );
                            await offlineSyncService.drainQueue(force: true);
                            ref
                                .read(
                                  offlineSyncQueueNotifierProvider.notifier,
                                )
                                .refreshQueueState();
                            final updatedState = await offlineSyncService
                                .getQueueState();
                            final countAfter = updatedState.items
                                .where(
                                  (i) =>
                                      i.status == QueueItemStatus.pending ||
                                      i.status == QueueItemStatus.retryableFailed,
                                )
                                .length;
                            final syncedCount = countBefore - countAfter;
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  syncedCount > 0
                                      ? 'Successfully synced $syncedCount items to server!'
                                      : 'Sync completed. Check queue status for details.',
                                ),
                              ),
                            );
                          },
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // 6. Security & Audit Logs
            if (_query.isEmpty ||
                'security audit log pin password encryption danger'.contains(
                  _query.toLowerCase(),
                ))
              AppSectionCard(
                title: 'Security & Audit Logs',
                icon: Icons.security_outlined,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Security & Data Privacy Controls'),
                    subtitle: const Text(
                      'Biometric PIN, local encryption, danger zone',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const SecurityBackupSheet(),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_outlined),
                    title: const Text('View Audit Logs'),
                    subtitle: const Text(
                      'Inspect immutable local security & mutation records',
                    ),
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
                                            return const AppEmptyState(
                                              icon: Icons.history_toggle_off,
                                              title: 'No Audit Logs Recorded',
                                              description:
                                                  'Local audit log records will appear here as mutations occur.',
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
                ],
              ),
            const SizedBox(height: 16),

            // 7. About & Diagnostics
            if (_query.isEmpty ||
                'about app version diagnostics build'.contains(
                  _query.toLowerCase(),
                ))
              AppSectionCard(
                title: 'About & Diagnostics',
                icon: Icons.info_outline,
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.phone_android_outlined),
                    title: Text('App Version'),
                    subtitle: Text('Lending Nelson v1.0.0 (Build 1)'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.copy_outlined),
                    title: const Text('Copy Diagnostics Info'),
                    subtitle: const Text(
                      'Copy sanitized environment & device state',
                    ),
                    onTap: () {
                      Clipboard.setData(
                        const ClipboardData(
                          text:
                              'Lending Nelson v1.0.0+1 | Flutter 3.x | Windows/Android',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Diagnostics copied to clipboard'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // 8. Logout Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                await ref.read(authRepositoryProvider).logout();
                if (!context.mounted) return;
                context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}
