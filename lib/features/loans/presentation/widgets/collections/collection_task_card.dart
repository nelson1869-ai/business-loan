import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';
import 'package:lending_nelson/features/dashboard/domain/dashboard_data.dart';
import 'collection_task_detail_sheet.dart';

/// Modern Collection Task Card with 1-tap quick actions and detail bottom sheet trigger.
class CollectionTaskCard extends StatelessWidget {
  final DashboardDueItem item;
  final bool isCompleted;
  final VoidCallback onComplete;

  const CollectionTaskCard({
    super.key,
    required this.item,
    required this.isCompleted,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => CollectionTaskDetailSheet.show(context, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: item.isOverdue
                    ? Colors.red.withValues(alpha: 0.15)
                    : colorScheme.primaryContainer,
                child: Text(
                  item.borrowerName.isNotEmpty
                      ? item.borrowerName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: item.isOverdue
                        ? Colors.red
                        : colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.borrowerName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Loan ID: ${item.loanId} · Inst #${item.installmentNumber}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppMoneyText(
                    amount: item.amountDue,
                    color: item.isOverdue ? Colors.red : null,
                  ),
                  const SizedBox(height: 2),
                  AppStatusChip(
                    status: isCompleted
                        ? 'Completed'
                        : item.isOverdue
                        ? 'Overdue'
                        : 'Pending',
                    isCompact: true,
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              const AppRiskBadge(riskGrade: 'Collection Visit'),
              const SizedBox(width: 6),
              if (item.isOverdue)
                const AppRiskBadge(riskGrade: 'High Priority')
              else
                const AppRiskBadge(riskGrade: 'Today'),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.point_of_sale_outlined, size: 16),
                    tooltip: 'Collect Payment',
                    onPressed: () =>
                        context.push('/loans/${item.loanId}/payments'),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.credit_card_outlined, size: 16),
                    tooltip: 'Open Loan',
                    onPressed: () => context.push('/loans/${item.loanId}'),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.check_outlined, size: 16),
                    tooltip: 'Mark Complete',
                    onPressed: isCompleted ? null : onComplete,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
