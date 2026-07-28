import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/models/loan.dart';

/// Header Card displaying loan identification, status badge, sync badge, and key dates.
class LoanHeaderCard extends StatelessWidget {
  final Loan loan;
  final VoidCallback? onRefresh;

  const LoanHeaderCard({super.key, required this.loan, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shortId = loan.id.length >= 8 ? loan.id.substring(0, 8) : loan.id;
    final statusColor = _getStatusColor(loan.status, colorScheme);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Loan Number & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Loan #$shortId',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Badge(label: loan.status, color: statusColor),
              ],
            ),
            const Divider(height: 20),
            // Details Rows
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Borrower ID',
              value: loan.borrowerId.length >= 8
                  ? loan.borrowerId.substring(0, 8)
                  : loan.borrowerId,
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'Loan Officer',
              value: 'Recorded by system',
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Disbursed',
                    value: formatDateShort(loan.startDate),
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    icon: Icons.event_available_outlined,
                    label: 'Maturity Date',
                    value: formatDateShort(loan.finalDueDate),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ColorScheme colors) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'overdue':
        return colors.error;
      case 'paid':
      case 'completed':
        return colors.primary;
      case 'pending':
        return Colors.orange;
      case 'defaulted':
        return Colors.purple;
      default:
        return colors.outline;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
