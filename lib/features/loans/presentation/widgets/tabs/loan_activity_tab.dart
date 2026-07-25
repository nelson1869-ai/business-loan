import 'package:flutter/material.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../domain/models/loan.dart';

/// Activity Tab View presenting chronological audit log timeline.
class LoanActivityTab extends StatelessWidget {
  final Loan loan;

  const LoanActivityTab({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final activities = [
      if (loan.status == 'Paid')
        _ActivityEvent(
          title: 'Loan Account Fully Paid & Closed',
          timestamp: '${formatDateShort(loan.finalDueDate)} 17:00',
          icon: Icons.task_alt,
          color: Colors.green,
        ),
      _ActivityEvent(
        title: 'Payment Transaction Synced to Server',
        timestamp: '2026-07-22 14:30',
        icon: Icons.cloud_done_outlined,
        color: Colors.teal,
      ),
      _ActivityEvent(
        title: 'Payment Receipt Recorded',
        timestamp: '2026-07-15 10:15',
        icon: Icons.payments_outlined,
        color: Colors.blue,
      ),
      _ActivityEvent(
        title: 'Loan Principal Disbursed',
        timestamp: '${formatDateShort(loan.startDate)} 09:00',
        icon: Icons.account_balance_wallet_outlined,
        color: Colors.purple,
      ),
      _ActivityEvent(
        title: 'Loan Agreement Approved & Created',
        timestamp: '${formatDateShort(loan.startDate)} 08:30',
        icon: Icons.assignment_turned_in_outlined,
        color: Colors.indigo,
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

class _ActivityEvent {
  final String title;
  final String timestamp;
  final IconData icon;
  final Color color;

  const _ActivityEvent({
    required this.title,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}
