import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../approvals/presentation/approval_provider.dart';
import 'create_action_sheet.dart';

/// Senior FinTech Dual-Mode Action Header (+ CREATE & ADMIN APPROVALS).
class DualModeActionHeader extends ConsumerWidget {
  const DualModeActionHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final approvalsState = ref.watch(approvalsProvider);
    final pendingApprovalsCount = approvalsState.maybeWhen(
      data: (list) => list.where((a) => a.status == 'pending').length,
      orElse: () => 0,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SINGLE-OWNER WORKFLOW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Sole Owner',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // 1. CREATE Button
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: () => CreateActionSheet.show(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0xFF0D9488).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 22),
                    label: const Text(
                      'CREATE',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. ADMIN APPROVALS Button
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: FilledButton.icon(
                          onPressed: () => context.push('/operations/approvals'),
                          style: FilledButton.styleFrom(
                            backgroundColor: pendingApprovalsCount > 0
                                ? const Color(0xFFD97706)
                                : (isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0)),
                            foregroundColor: pendingApprovalsCount > 0
                                ? Colors.white
                                : (isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B)),
                            elevation: pendingApprovalsCount > 0 ? 4 : 0,
                            shadowColor: pendingApprovalsCount > 0
                                ? const Color(0xFFD97706).withValues(alpha: 0.4)
                                : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.shield_rounded, size: 20),
                          label: const Text(
                            'ADMIN',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
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
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : Colors.white,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              '$pendingApprovalsCount PENDING',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
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
