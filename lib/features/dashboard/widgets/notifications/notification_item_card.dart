import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

class NotificationItemModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String time;
  final String priority;
  final String? borrowerId;
  final String? borrowerName;
  final String? loanId;
  final bool isRead;

  NotificationItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.time,
    required this.priority,
    this.borrowerId,
    this.borrowerName,
    this.loanId,
    this.isRead = false,
  });
}

/// Notification Item Card component with 1-tap quick actions.
class NotificationItemCard extends StatelessWidget {
  final NotificationItemModel item;
  final VoidCallback onMarkRead;

  const NotificationItemCard({
    super.key,
    required this.item,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color priorityColor = Colors.blue;
    if (item.priority == 'Critical' || item.priority == 'High') {
      priorityColor = Colors.red;
    } else if (item.priority == 'Medium') {
      priorityColor = Colors.orange;
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderColor: item.isRead ? null : priorityColor.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: priorityColor.withValues(alpha: 0.15),
                child: Icon(
                  _getCategoryIcon(item.category),
                  size: 18,
                  color: priorityColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: item.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          item.time,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.borrowerName != null || item.loanId != null) ...[
            const Divider(height: 14),
            Row(
              children: [
                if (item.borrowerName != null)
                  AppStatusChip(status: item.borrowerName!, isCompact: true),
                const SizedBox(width: 6),
                if (item.loanId != null)
                  AppRiskBadge(riskGrade: 'Loan #${item.loanId}'),
                const Spacer(),
                // Quick Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.loanId != null)
                      IconButton.filledTonal(
                        icon: const Icon(
                          Icons.point_of_sale_outlined,
                          size: 16,
                        ),
                        tooltip: 'Collect Payment',
                        onPressed: () =>
                            context.push('/loans/${item.loanId}/payments'),
                      ),
                    const SizedBox(width: 4),
                    if (item.borrowerId != null)
                      IconButton.filledTonal(
                        icon: const Icon(Icons.person_outline, size: 16),
                        tooltip: 'Open Borrower',
                        onPressed: () =>
                            context.push('/borrowers/${item.borrowerId}'),
                      ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      icon: Icon(
                        item.isRead
                            ? Icons.mark_email_read_outlined
                            : Icons.mark_email_unread_outlined,
                        size: 16,
                      ),
                      tooltip: item.isRead ? 'Already Read' : 'Mark Read',
                      onPressed: onMarkRead,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'overdue':
        return Icons.warning_amber_outlined;
      case 'collections':
        return Icons.payments_outlined;
      case 'sync':
        return Icons.sync_problem_outlined;
      case 'approvals':
        return Icons.verified_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }
}
