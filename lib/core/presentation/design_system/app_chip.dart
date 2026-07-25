import 'package:flutter/material.dart';

/// Universal Status Chip component across all features.
class AppStatusChip extends StatelessWidget {
  final String status;
  final bool isCompact;

  const AppStatusChip({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color color = Colors.grey;
    IconData? icon;

    switch (status.toLowerCase()) {
      case 'active':
      case 'paid':
      case 'synced':
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case 'overdue':
      case 'failed':
      case 'critical':
        color = colorScheme.error;
        icon = Icons.error_outline;
        break;
      case 'pending':
      case 'pending sync':
      case 'offline':
      case 'watch':
        color = Colors.orange;
        icon = Icons.cloud_off_outlined;
        break;
      case 'reversal':
      case 'reversed':
        color = Colors.purple;
        icon = Icons.undo;
        break;
      default:
        color = colorScheme.primary;
        icon = Icons.info_outline;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 10,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 11 : 13, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Universal Risk Grade Badge component.
class AppRiskBadge extends StatelessWidget {
  final String riskGrade;

  const AppRiskBadge({super.key, required this.riskGrade});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.green;
    if (riskGrade.contains('High') || riskGrade.contains('Critical')) {
      color = Colors.red;
    } else if (riskGrade.contains('Medium') || riskGrade.contains('Watch')) {
      color = Colors.orange;
    } else if (riskGrade.contains('Low') || riskGrade.contains('Good')) {
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        riskGrade.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

/// Standardized Filter Chip component for list filtering.
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? theme.colorScheme.onPrimaryContainer : null,
      ),
    );
  }
}
