import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

/// Responsive Grid displaying Notification Summary Metrics.
class NotificationSummaryCards extends StatelessWidget {
  const NotificationSummaryCards({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: constraints.maxWidth > 600 ? 2.2 : 1.8,
          children: [
            AppMetricCard(
              label: 'Unread Alerts',
              value: '3 Unread',
              icon: Icons.mark_email_unread_outlined,
              color: theme.colorScheme.primary,
            ),
            AppMetricCard(
              label: 'Overdue Warnings',
              value: '2 Overdue',
              icon: Icons.warning_amber_outlined,
              color: Colors.red,
            ),
            AppMetricCard(
              label: 'High Priority',
              value: '1 Critical',
              icon: Icons.priority_high,
              color: Colors.orange.shade800,
            ),
            AppMetricCard(
              label: 'System Status',
              value: 'All Systems OK',
              icon: Icons.cloud_done_outlined,
              color: Colors.green,
            ),
          ],
        );
      },
    );
  }
}
