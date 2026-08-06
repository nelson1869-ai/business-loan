import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PortfolioSummaryCards extends StatelessWidget {
  const PortfolioSummaryCards({
    super.key,
    required this.activeBorrowers,
    required this.outstandingBalance,
    required this.overdueCount,
    required this.overdueAmount,
    required this.collectionDueToday,
    required this.collectionCountToday,
    required this.totalActiveLoanCount,
  });

  final int activeBorrowers;
  final String outstandingBalance;
  final int overdueCount;
  final String overdueAmount;
  final String collectionDueToday;
  final int collectionCountToday;
  final int totalActiveLoanCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _Card(
              icon: Icons.people_outline,
              label: 'Borrowers',
              value: '$activeBorrowers',
              color: const Color(0xFF0D9488),
              onTap: () => context.go('/borrowers'),
            ),
            _Card(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Outstanding',
              value: _formatCurrency(outstandingBalance),
              color: const Color(0xFF0F172A),
              onTap: () => context.go('/loans'),
            ),
            _Card(
              icon: Icons.warning_amber_rounded,
              label: 'Overdue ($overdueCount)',
              value: _formatCurrency(overdueAmount),
              color: const Color(0xFFEF4444),
              onTap: () => context.go('/loans?status=overdue'),
            ),
            _Card(
              icon: Icons.today_outlined,
              label: 'Due Today ($collectionCountToday)',
              value: _formatCurrency(collectionDueToday),
              color: const Color(0xFF3B82F6),
              onTap: () => context.push('/collections/today'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PortfolioProgressBar(
          totalCount: totalActiveLoanCount,
          overdueCount: overdueCount,
        ),
      ],
    );
  }

  String _formatCurrency(String amount) {
    final value = double.tryParse(amount) ?? 0;
    if (value >= 1000000) {
      return '₱${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '₱${(value / 1000).toStringAsFixed(1)}K';
    }
    return '₱${value.toStringAsFixed(0)}';
  }
}

class _PortfolioProgressBar extends StatelessWidget {
  const _PortfolioProgressBar({
    required this.totalCount,
    required this.overdueCount,
  });

  final int totalCount;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onTimeCount = (totalCount - overdueCount).clamp(0, totalCount);
    final ratio = totalCount > 0 ? onTimeCount / totalCount : 0.0;
    final pct = (ratio * 100).round();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  'Portfolio Collection Health',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                Text(
                  totalCount > 0 ? '$pct% On-Time' : 'No active loans',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: totalCount == 0
                  ? Container(
                      height: 10,
                      color: theme.colorScheme.surfaceContainerHighest,
                    )
                  : SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          if (onTimeCount > 0)
                            Expanded(
                              flex: onTimeCount,
                              child: Container(
                                color: isDark
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF059669),
                              ),
                            ),
                          if (overdueCount > 0)
                            Expanded(
                              flex: overdueCount,
                              child: Container(
                                color: isDark
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _LegendDot(
                  color: isDark
                      ? const Color(0xFF10B981)
                      : const Color(0xFF059669),
                ),
                const SizedBox(width: 4),
                Text('$onTimeCount On-Time', style: _legendText(theme, isDark)),
                const Spacer(),
                _LegendDot(
                  color: isDark
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 4),
                Text(
                  '$overdueCount Overdue',
                  style: _legendText(theme, isDark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _legendText(ThemeData theme, bool isDark) => TextStyle(
    fontSize: 11,
    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : color,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
