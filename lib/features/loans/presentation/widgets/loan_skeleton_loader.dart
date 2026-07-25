import 'package:flutter/material.dart';

/// Skeleton loading placeholder for Loan Details Page.
class LoanSkeletonLoader extends StatelessWidget {
  const LoanSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.6,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Skeleton
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 120, height: 20, color: baseColor),
                    const Spacer(),
                    Container(width: 70, height: 20, color: baseColor),
                  ],
                ),
                const SizedBox(height: 12),
                Container(width: 160, height: 14, color: baseColor),
                const SizedBox(height: 6),
                Container(width: 100, height: 12, color: baseColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Metrics Grid Skeleton
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: List.generate(
            4,
            (_) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 70, height: 10, color: baseColor),
                    const SizedBox(height: 6),
                    Container(width: 90, height: 16, color: baseColor),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Progress Section Skeleton
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 130, height: 14, color: baseColor),
                const SizedBox(height: 10),
                Container(width: double.infinity, height: 12, color: baseColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
