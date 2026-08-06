import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../approvals/presentation/approval_provider.dart';
import 'create_action_sheet.dart';

/// Single-owner primary dual-action header (+ CREATE & ADMIN APPROVALS).
class DualModeActionHeader extends ConsumerWidget {
  const DualModeActionHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final approvalsState = ref.watch(approvalsProvider);
    final pendingApprovalsCount = approvalsState.maybeWhen(
      data: (list) => list.where((a) => a.status == 'pending').length,
      orElse: () => 0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SINGLE-OWNER WORKFLOW',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.person_pin_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Administrator',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // 1. CREATE Button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => CreateActionSheet.show(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.add_circle, size: 24),
                    label: const Text(
                      '+ CREATE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. ADMIN APPROVALS Button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: FilledButton.tonalIcon(
                          onPressed: () => context.push('/operations/approvals'),
                          style: FilledButton.styleFrom(
                            backgroundColor: pendingApprovalsCount > 0
                                ? Colors.amber.shade100
                                : theme.colorScheme.secondaryContainer,
                            foregroundColor: pendingApprovalsCount > 0
                                ? Colors.amber.shade900
                                : theme.colorScheme.onSecondaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: Icon(
                            Icons.verified_user,
                            size: 22,
                            color: pendingApprovalsCount > 0
                                ? Colors.amber.shade900
                                : theme.colorScheme.onSecondaryContainer,
                          ),
                          label: const Text(
                            'ADMIN',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      if (pendingApprovalsCount > 0)
                        Positioned(
                          top: -6,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Text(
                              '$pendingApprovalsCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
