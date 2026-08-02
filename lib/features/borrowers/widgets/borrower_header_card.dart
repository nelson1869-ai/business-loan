import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/borrower_model.dart';
import '../domain/borrower_recommendation.dart';
import '../providers/borrowers_state.dart';
import 'pii_masked_text.dart';

/// Material 3 Header Card for Borrower Profile.
class BorrowerHeaderCard extends ConsumerWidget {
  final Borrower borrower;
  final BorrowerRecommendation? recommendation;

  const BorrowerHeaderCard({
    super.key,
    required this.borrower,
    this.recommendation,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _getStatusColor(borrower.status, colorScheme);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar, Name, Badges & Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    _initials(borrower.fullName),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        borrower.fullName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Badge(
                            label: borrower.isServerVerified
                                ? borrower.status
                                : 'Pending verification',
                            color: borrower.isServerVerified
                                ? statusColor
                                : Colors.orange,
                          ),
                          if (recommendation != null)
                            _Badge(
                              label: recommendation!.riskTier.label,
                              color: _getRiskColor(
                                recommendation!.riskTier,
                                colorScheme,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (val) => _handleMenuAction(context, ref, val),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Edit Borrower'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete Borrower',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text('Call'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Calling ${borrower.fullName}...'),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.sms_outlined, size: 18),
                  label: const Text('Message'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sending SMS to ${borrower.fullName}...'),
                      ),
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 24),
            // Masked Information Section
            PIIMaskedText(
              icon: Icons.badge_outlined,
              label: 'National ID',
              value: borrower.nationalId,
            ),
            const SizedBox(height: 6),
            PIIMaskedText(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: borrower.phone,
              isPhone: true,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'DOB: ${borrower.dateOfBirth}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    if (action == 'edit') {
      context.push('/borrowers/register', extra: borrower);
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Borrower Profile'),
          content: Text(
            'Are you sure you want to permanently delete "${borrower.fullName}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true && context.mounted) {
        try {
          await ref
              .read(borrowersNotifierProvider.notifier)
              .deleteBorrower(borrower.id);
          if (context.mounted) {
            context.go('/borrowers');
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Delete failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  Color _getStatusColor(String status, ColorScheme colors) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'overdue':
        return colors.error;
      case 'completed':
        return colors.primary;
      default:
        return colors.outline;
    }
  }

  Color _getRiskColor(RiskTier tier, ColorScheme colors) {
    switch (tier) {
      case RiskTier.lowRisk:
        return Colors.teal;
      case RiskTier.mediumRisk:
        return colors.primary;
      case RiskTier.highRisk:
        return Colors.orange;
      case RiskTier.criticalRisk:
        return colors.error;
      case RiskTier.newBorrower:
        return Colors.blue;
    }
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
