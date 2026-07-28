import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lending_nelson/core/presentation/design_system/design_system.dart';
import 'package:lending_nelson/core/network/api_error_mapper.dart';
import 'package:lending_nelson/core/network/server_health_service.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';
import '../providers/notification_provider.dart';
import '../widgets/notifications/notification_filter_bar.dart';
import '../widgets/notifications/notification_header_card.dart';
import '../widgets/notifications/notification_item_card.dart';
import '../widgets/notifications/notification_summary_cards.dart';

/// Notifications & Reminder Center Page.
class NotificationsCenterPage extends ConsumerStatefulWidget {
  const NotificationsCenterPage({super.key});

  @override
  ConsumerState<NotificationsCenterPage> createState() =>
      _NotificationsCenterPageState();
}

class _NotificationsCenterPageState
    extends ConsumerState<NotificationsCenterPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedFilter = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final notifications =
        notificationsAsync.valueOrNull ?? const <AppNotification>[];
    final isServerReady =
        ref.watch(serverStatusNotifierProvider) == ServerStatus.serverReady;
    final filteredItems = notifications.where((n) {
      if (_selectedFilter == 'Unread' && n.isRead) {
        return false;
      }
      if (_selectedFilter == 'High Priority' &&
          (n.priority != 'Critical' && n.priority != 'High')) {
        return false;
      }
      if (_selectedFilter == 'Today' && !_isToday(n.createdAt)) {
        return false;
      }
      if (const {
            'Collections',
            'Borrowers',
            'Loans',
            'System',
          }.contains(_selectedFilter) &&
          n.category.toLowerCase() != _selectedFilter.toLowerCase()) {
        return false;
      }
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matchTitle = n.title.toLowerCase().contains(q);
        final matchDesc = n.body.toLowerCase().contains(q);
        if (!matchTitle && !matchDesc) return false;
      }
      return true;
    }).toList();
    final unreadCount = notifications.where((n) => !n.isRead).length;
    final overdueCount = notifications
        .where((n) => n.category == 'Overdue')
        .length;
    final highPriorityCount = notifications
        .where((n) => n.priority == 'Critical' || n.priority == 'High')
        .length;

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
        title: const Text('Notifications & Reminders'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          await ref.read(notificationsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Notification Header & Search Card
            NotificationHeaderCard(
              searchController: _searchCtrl,
              onSearchChanged: (v) => setState(() => _query = v),
              unreadCount: unreadCount,
              onMarkAllRead: () async {
                if (unreadCount == 0) return;
                await ref.read(notificationRepositoryProvider).markAllRead();
                ref.invalidate(notificationsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 14),
            // 2. Summary Metric Cards
            NotificationSummaryCards(
              unreadCount: unreadCount,
              overdueCount: overdueCount,
              highPriorityCount: highPriorityCount,
              isServerReady: isServerReady,
            ),
            const SizedBox(height: 16),
            // 3. Multi-Category Filter Bar
            NotificationFilterBar(
              selectedFilter: _selectedFilter,
              onFilterChanged: (v) => setState(() => _selectedFilter = v),
            ),
            const SizedBox(height: 14),
            // 4. Notification List Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Alerts & Activity (${filteredItems.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Sorted by Time',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (notificationsAsync.isLoading)
              const Column(
                children: [
                  AppCardSkeleton(),
                  SizedBox(height: 10),
                  AppCardSkeleton(),
                  SizedBox(height: 10),
                  AppCardSkeleton(),
                ],
              )
            else if (notificationsAsync.hasError)
              AppErrorState(
                error: ApiErrorMapper.message(notificationsAsync.error!),
                onRetry: () => ref.invalidate(notificationsProvider),
              )
            else if (filteredItems.isEmpty)
              AppEmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'No Notifications',
                description: _query.isNotEmpty || _selectedFilter != 'All'
                    ? 'No notifications match the current filters.'
                    : 'New collection alerts and reminders will appear here.',
                actionLabel: _query.isNotEmpty || _selectedFilter != 'All'
                    ? 'Reset Filters'
                    : null,
                onAction: _query.isNotEmpty || _selectedFilter != 'All'
                    ? () {
                        _searchCtrl.clear();
                        setState(() {
                          _query = '';
                          _selectedFilter = 'All';
                        });
                      }
                    : null,
              )
            else
              ...filteredItems.map(
                (n) => NotificationItemCard(
                  item: _toItemModel(n),
                  onMarkRead: () async {
                    if (n.isRead) return;
                    await ref
                        .read(notificationRepositoryProvider)
                        .markRead(n.id);
                    ref.invalidate(notificationsProvider);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  NotificationItemModel _toItemModel(AppNotification notification) {
    final created = notification.createdAt;
    final now = DateTime.now();
    final time =
        created.year == now.year &&
            created.month == now.month &&
            created.day == now.day
        ? '${created.hour.toString().padLeft(2, '0')}:'
              '${created.minute.toString().padLeft(2, '0')}'
        : '${created.month}/${created.day}/${created.year}';
    return NotificationItemModel(
      id: notification.id,
      title: notification.title,
      description: notification.body,
      category: notification.category,
      time: time,
      priority: notification.priority,
      borrowerId: notification.borrowerId,
      loanId: notification.loanId,
      isRead: notification.isRead,
    );
  }

  bool _isToday(DateTime value) {
    const businessOffset = Duration(hours: 8);
    final now = DateTime.now().toUtc().add(businessOffset);
    final date = value.toUtc().add(businessOffset);
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
