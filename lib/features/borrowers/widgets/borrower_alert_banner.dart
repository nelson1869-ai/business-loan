import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';

/// Material 3 Alert Banner for Overdue Borrowers.
class BorrowerAlertBanner extends StatelessWidget {
  final int daysOverdue;
  final String overdueAmount;
  final String recommendedNextAction;
  final VoidCallback? onTakeAction;

  const BorrowerAlertBanner({
    super.key,
    required this.daysOverdue,
    required this.overdueAmount,
    required this.recommendedNextAction,
    this.onTakeAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.red.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Payment Overdue ($daysOverdue Days Late)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Amount Due: ${formatCurrency(overdueAmount)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade900,
                    ),
                  ),
                  if (recommendedNextAction.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Action: $recommendedNextAction',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTakeAction != null)
              FilledButton.tonal(
                onPressed: onTakeAction,
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.red.shade900,
                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                child: const Text('Resolve', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
