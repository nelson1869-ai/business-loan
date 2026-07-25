import 'package:flutter/material.dart';
import '../domain/borrower_model.dart';
import '../domain/borrower_recommendation.dart';

/// Scorecard presenting Relationship Score, Payment Score, Collection Score, Reliability, and Risk Status Badges.
class BorrowerCustomerScoreCard extends StatelessWidget {
  final Borrower borrower;
  final BorrowerRecommendation? recommendation;

  const BorrowerCustomerScoreCard({
    super.key,
    required this.borrower,
    this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tier = recommendation?.eligibilityStatus.label ?? 'Standard Customer';
    final riskLevel = recommendation?.riskTier.label ?? borrower.status;
    final creditScore = recommendation != null
        ? '${recommendation!.creditScore}/100'
        : '94/100';

    Color badgeColor = Colors.green;
    if (riskLevel.contains('High') || riskLevel.contains('Critical')) {
      badgeColor = Colors.red;
    } else if (riskLevel.contains('Medium')) {
      badgeColor = Colors.orange;
    } else if (riskLevel.contains('Low')) {
      badgeColor = Colors.blue;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: badgeColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.workspace_premium_outlined,
                  color: badgeColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Customer 360° Credit Score',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tier.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 12,
              runSpacing: 12,
              children: [
                _ScoreGauge(
                  label: 'Payment Score',
                  score: creditScore,
                  color: Colors.green,
                ),
                _ScoreGauge(
                  label: 'Relationship',
                  score: '5 Yrs',
                  color: colorScheme.primary,
                ),
                _ScoreGauge(
                  label: 'Collection Score',
                  score: 'A+',
                  color: Colors.teal,
                ),
                _ScoreGauge(
                  label: 'Risk Grade',
                  score: riskLevel,
                  color: badgeColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreGauge extends StatelessWidget {
  final String label;
  final String score;
  final Color color;

  const _ScoreGauge({
    required this.label,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          score,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
