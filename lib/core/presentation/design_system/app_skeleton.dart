import 'package:flutter/material.dart';
import 'app_card.dart';

/// Universal Skeleton Loading placeholder widgets for smooth M3 loading states.
class AppLoadingSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const AppLoadingSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.6,
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Standardized Card Skeleton placeholder.
class AppCardSkeleton extends StatelessWidget {
  const AppCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: Colors.black12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppLoadingSkeleton(width: 120, height: 14),
                    SizedBox(height: 6),
                    AppLoadingSkeleton(width: 80, height: 10),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          AppLoadingSkeleton(width: double.infinity, height: 36),
        ],
      ),
    );
  }
}
