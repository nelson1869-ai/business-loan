import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

/// Notification Header Card with search bar, unread count, and Mark All Read trigger.
class NotificationHeaderCard extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onMarkAllRead;
  final int unreadCount;

  const NotificationHeaderCard({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onMarkAllRead,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications & Alerts Center',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Central Communication Hub',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusChip(status: '$unreadCount Unread'),
            ],
          ),
          const SizedBox(height: 14),
          // Search Input Bar
          AppSearchBar(
            controller: searchController,
            hintText: 'Search by borrower, loan, or alert type...',
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: unreadCount > 0 ? onMarkAllRead : null,
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text('Mark All Read'),
              ),
              TextButton.icon(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Notification Preferences'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
