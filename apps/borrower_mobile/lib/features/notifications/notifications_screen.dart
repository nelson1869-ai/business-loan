import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:borrower_mobile/features/notifications/models/borrower_notification.dart';
import 'package:borrower_mobile/features/notifications/providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsNotifierProvider);
    final notifier = ref.read(notificationsNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: () {
                notifier.markAllAsRead();
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await notifier.loadNotifications(isRefresh: true);
        },
        child: _buildBody(context, ref, state, notifier),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    NotificationsState state,
    NotificationsNotifier notifier,
  ) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    state.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    notifier.loadNotifications();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (state.notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'We will notify you about payment receipts, loan updates, and account alerts here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final dateFormat = DateFormat('MMM dd, yyyy • h:mm a');

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: state.notifications.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = state.notifications[index];
        final iconData = _getNotificationIcon(item.notificationType);
        final iconColor = _getNotificationColor(item.notificationType);

        return Material(
          color: item.isRead
              ? Theme.of(context).scaffoldBackgroundColor
              : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: iconColor.withValues(alpha: 0.15),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            title: Text(
              item.title,
              style: TextStyle(
                fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  item.message,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dateFormat.format(item.createdAt.toLocal()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: item.isRead
                ? null
                : Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
            onTap: () {
              notifier.markAsRead(item.id);
              _handleNotificationTap(context, item);
            },
          ),
        );
      },
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'payment_receipt':
        return Icons.receipt_long;
      case 'payment_reversal':
        return Icons.history;
      case 'loan_activated':
        return Icons.account_balance_wallet;
      case 'loan_request_submitted':
      case 'loan_request_approved':
      case 'loan_request_declined':
        return Icons.request_quote;
      case 'registration_approved':
      case 'account_activated':
        return Icons.verified_user;
      case 'pin_reset_requested':
        return Icons.security;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'payment_receipt':
        return Colors.green;
      case 'payment_reversal':
        return Colors.orange;
      case 'loan_activated':
        return Colors.indigo;
      case 'loan_request_submitted':
      case 'loan_request_approved':
        return Colors.teal;
      case 'loan_request_declined':
        return Colors.redAccent;
      case 'registration_approved':
      case 'account_activated':
        return Colors.purple;
      case 'pin_reset_requested':
        return Colors.amber;
      default:
        return Colors.blueGrey;
    }
  }

  void _handleNotificationTap(
      BuildContext context, BorrowerNotificationItem item) {
    final type = item.notificationType;
    final entityType = item.entityType;
    final entityId =
        item.entityId ?? item.loanId ?? item.receiptId ?? item.requestId;

    if (type == 'payment_receipt' ||
        type == 'payment_reversal' ||
        entityType == 'receipt' ||
        entityType == 'payment') {
      context.push('/payments');
    } else if (type == 'loan_activated' || entityType == 'loan') {
      if (entityId != null && entityId.isNotEmpty) {
        context.push('/loans/$entityId');
      } else {
        context.push('/loans');
      }
    } else if (type.startsWith('loan_request') || entityType == 'loan_request') {
      context.push('/loans');
    } else if (type == 'registration_approved' ||
        type == 'account_activated' ||
        entityType == 'registration' ||
        entityType == 'borrower_account') {
      context.push('/home');
    } else if (type == 'pin_reset_requested') {
      context.push('/profile');
    } else {
      // Unknown notification type renders safely without navigating or crashing
    }
  }
}
