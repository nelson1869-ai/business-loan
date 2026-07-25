import 'package:flutter/material.dart';
import '../../domain/borrower_model.dart';

/// Activity Tab View presenting chronological system audit logs.
class ActivityTabView extends StatelessWidget {
  final Borrower borrower;

  const ActivityTabView({super.key, required this.borrower});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final activities = [
      _ActivityItem(
        title: 'Borrower Profile Updated',
        timestamp: '2026-07-22 14:10',
        icon: Icons.edit_note,
        color: Colors.blue,
      ),
      _ActivityItem(
        title: 'Payment Receipt Recorded',
        timestamp: '2026-07-15 09:30',
        icon: Icons.payments,
        color: Colors.green,
      ),
      _ActivityItem(
        title: 'Loan Agreement Approved',
        timestamp: '2026-06-10 11:45',
        icon: Icons.check_circle_outline,
        color: Colors.purple,
      ),
      _ActivityItem(
        title: 'Borrower Registration Created',
        timestamp:
            '${borrower.createdAt.length >= 10 ? borrower.createdAt.substring(0, 10) : borrower.createdAt} 08:00',
        icon: Icons.person_add_alt,
        color: Colors.teal,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final item = activities[index];
        final isLast = index == activities.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: item.color.withValues(alpha: 0.15),
                  child: Icon(item.icon, size: 16, color: item.color),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 45,
                    color: theme.colorScheme.outlineVariant,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.timestamp,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActivityItem {
  final String title;
  final String timestamp;
  final IconData icon;
  final Color color;

  const _ActivityItem({
    required this.title,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}
