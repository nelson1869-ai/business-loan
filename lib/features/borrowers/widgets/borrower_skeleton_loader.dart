import 'package:flutter/material.dart';

/// Skeleton loading placeholder for the Borrower Profile Page.
class BorrowerSkeletonLoader extends StatelessWidget {
  const BorrowerSkeletonLoader({super.key});

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
            child: Row(
              children: [
                CircleAvatar(radius: 28, backgroundColor: baseColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 140, height: 18, color: baseColor),
                      const SizedBox(height: 8),
                      Container(width: 100, height: 12, color: baseColor),
                      const SizedBox(height: 6),
                      Container(width: 120, height: 12, color: baseColor),
                    ],
                  ),
                ),
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
                    Container(width: 80, height: 10, color: baseColor),
                    const SizedBox(height: 6),
                    Container(width: 60, height: 16, color: baseColor),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Tab Content Skeleton
        Card(
          child: Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 120, height: 16, color: baseColor),
                const SizedBox(height: 12),
                Container(width: double.infinity, height: 12, color: baseColor),
                const SizedBox(height: 8),
                Container(width: 200, height: 12, color: baseColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
