import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lending_nelson/core/presentation/design_system/design_system.dart';
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

  final List<NotificationItemModel> _notifications = [
    NotificationItemModel(
      id: '1',
      title: 'Collection Due Today — Maria Santos',
      description:
          'Scheduled installment payment of ₱1,250.00 due today at 9:00 AM.',
      category: 'Collections',
      time: '10 mins ago',
      priority: 'High',
      borrowerId: 'b-01',
      borrowerName: 'Maria Santos',
      loanId: 'L-1001',
      isRead: false,
    ),
    NotificationItemModel(
      id: '2',
      title: 'Overdue Loan Warning — Juan Dela Cruz',
      description:
          'Installment #3 is 14 days overdue. Outstanding balance ₱3,500.00.',
      category: 'Overdue',
      time: '1 hour ago',
      priority: 'Critical',
      borrowerId: 'b-02',
      borrowerName: 'Juan Dela Cruz',
      loanId: 'L-1002',
      isRead: false,
    ),
    NotificationItemModel(
      id: '3',
      title: 'Promise To Pay Today — Pedro Penduko',
      description:
          'Borrower promised to pay ₱2,000.00 installment before 4:00 PM.',
      category: 'Collections',
      time: '3 hours ago',
      priority: 'Medium',
      borrowerId: 'b-03',
      borrowerName: 'Pedro Penduko',
      loanId: 'L-1003',
      isRead: false,
    ),
    NotificationItemModel(
      id: '4',
      title: 'Offline Sync Completed',
      description:
          '4 offline payment audit logs successfully synced with server.',
      category: 'Sync',
      time: 'Yesterday',
      priority: 'Low',
      isRead: true,
    ),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _notifications.where((n) {
      if (_selectedFilter == 'Unread' && n.isRead) {
        return false;
      }
      if (_selectedFilter == 'High Priority' &&
          (n.priority != 'Critical' && n.priority != 'High')) {
        return false;
      }
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matchTitle = n.title.toLowerCase().contains(q);
        final matchDesc = n.description.toLowerCase().contains(q);
        final matchName = n.borrowerName?.toLowerCase().contains(q) ?? false;
        if (!matchTitle && !matchDesc && !matchName) return false;
      }
      return true;
    }).toList();

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
          setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Notification Header & Search Card
            NotificationHeaderCard(
              searchController: _searchCtrl,
              onSearchChanged: (v) => setState(() => _query = v),
              onMarkAllRead: () {
                setState(() {
                  for (var i = 0; i < _notifications.length; i++) {
                    _notifications[i] = NotificationItemModel(
                      id: _notifications[i].id,
                      title: _notifications[i].title,
                      description: _notifications[i].description,
                      category: _notifications[i].category,
                      time: _notifications[i].time,
                      priority: _notifications[i].priority,
                      borrowerId: _notifications[i].borrowerId,
                      borrowerName: _notifications[i].borrowerName,
                      loanId: _notifications[i].loanId,
                      isRead: true,
                    );
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            // 2. Summary Metric Cards
            const NotificationSummaryCards(),
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
            if (filteredItems.isEmpty)
              AppEmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'No Notifications Found',
                description:
                    'You have no alerts matching the selected filter or search criteria.',
                actionLabel: 'Reset Filters',
                onAction: () {
                  _searchCtrl.clear();
                  setState(() {
                    _query = '';
                    _selectedFilter = 'All';
                  });
                },
              )
            else
              ...filteredItems.map(
                (n) => NotificationItemCard(
                  item: n,
                  onMarkRead: () {
                    setState(() {
                      final idx = _notifications.indexWhere(
                        (x) => x.id == n.id,
                      );
                      if (idx != -1) {
                        _notifications[idx] = NotificationItemModel(
                          id: n.id,
                          title: n.title,
                          description: n.description,
                          category: n.category,
                          time: n.time,
                          priority: n.priority,
                          borrowerId: n.borrowerId,
                          borrowerName: n.borrowerName,
                          loanId: n.loanId,
                          isRead: true,
                        );
                      }
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
