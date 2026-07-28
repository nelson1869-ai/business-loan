import 'package:flutter/material.dart';
import '../domain/borrower_recommendation.dart';

class BorrowerRecommendationCard extends StatelessWidget {
  final BorrowerRecommendation recommendation;
  final VoidCallback? onApplyRecommended;

  const BorrowerRecommendationCard({
    super.key,
    required this.recommendation,
    this.onApplyRecommended,
  });

  @override
  Widget build(BuildContext meContext) {
    final theme = Theme.of(meContext);
    final colorScheme = _getTierColorScheme(recommendation.riskTier);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.06),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row: Badge & Score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        _getTierIcon(recommendation.riskTier),
                        color: colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Recommendation System',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Score: ${recommendation.creditScore}/100',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tier & Status Row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  label: Text(recommendation.riskTier.label),
                  backgroundColor: colorScheme.container,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  padding: EdgeInsets.zero,
                ),
                Chip(
                  avatar: Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  label: Text(recommendation.eligibilityStatus.label),
                  backgroundColor: colorScheme.container,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const Divider(height: 20),

            // Limits Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context: meContext,
                    label: 'Max Recommended',
                    value: _formatCurrency(
                      double.tryParse(recommendation.maxRecommendedPrincipal) ??
                          0,
                    ),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    context: meContext,
                    label: 'Suggested Monthly Rate',
                    value:
                        '${(double.tryParse(recommendation.suggestedMonthlyRate) ?? 0.0) * 100}%',
                    icon: Icons.percent_outlined,
                  ),
                ),
              ],
            ),

            if (recommendation.recommendationReasons.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Assessment Factors:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              ...recommendation.recommendationReasons.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(reason, style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (recommendation.suggestedNextActions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Recommended Actions:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              ...recommendation.suggestedNextActions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.arrow_right,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      Expanded(
                        child: Text(
                          action,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (onApplyRecommended != null &&
                recommendation.eligibilityStatus !=
                    EligibilityStatus.declined) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onApplyRecommended,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Apply Recommended Terms'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
                maxLines: 2,
              ),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final digits = parts.first;
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[index]);
    }
    return '\$$buffer.${parts.last}';
  }

  _TierColorScheme _getTierColorScheme(RiskTier tier) {
    switch (tier) {
      case RiskTier.lowRisk:
        return const _TierColorScheme(
          primary: Colors.teal,
          container: Color(0xFFE0F2F1),
        );
      case RiskTier.mediumRisk:
        return const _TierColorScheme(
          primary: Colors.indigo,
          container: Color(0xFFE8EAF6),
        );
      case RiskTier.highRisk:
        return const _TierColorScheme(
          primary: Colors.orange,
          container: Color(0xFFFFF3E0),
        );
      case RiskTier.criticalRisk:
        return const _TierColorScheme(
          primary: Colors.red,
          container: Color(0xFFFFEBEE),
        );
      case RiskTier.newBorrower:
        return const _TierColorScheme(
          primary: Colors.blue,
          container: Color(0xFFE3F2FD),
        );
    }
  }

  IconData _getTierIcon(RiskTier tier) {
    switch (tier) {
      case RiskTier.lowRisk:
        return Icons.stars_rounded;
      case RiskTier.mediumRisk:
        return Icons.thumb_up_alt_outlined;
      case RiskTier.highRisk:
        return Icons.warning_amber_rounded;
      case RiskTier.criticalRisk:
        return Icons.gpp_bad_rounded;
      case RiskTier.newBorrower:
        return Icons.person_add_alt_1_rounded;
    }
  }
}

class _TierColorScheme {
  final Color primary;
  final Color container;

  const _TierColorScheme({required this.primary, required this.container});
}
