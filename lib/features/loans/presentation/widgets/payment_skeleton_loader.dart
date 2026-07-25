import 'package:flutter/material.dart';

/// Skeleton loading placeholder for Payment Collection Page.
class PaymentSkeletonLoader extends StatelessWidget {
  const PaymentSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.6,
    );

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      children: [
        // Borrower Header Skeleton
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(radius: 24, backgroundColor: baseColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 130, height: 16, color: baseColor),
                      const SizedBox(height: 6),
                      Container(width: 90, height: 12, color: baseColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Payment Form Skeleton
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 140, height: 18, color: baseColor),
                const SizedBox(height: 12),
                Container(width: double.infinity, height: 48, color: baseColor),
                const SizedBox(height: 12),
                Container(width: double.infinity, height: 40, color: baseColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
