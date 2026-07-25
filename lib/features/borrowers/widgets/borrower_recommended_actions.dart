import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../domain/borrower_model.dart';

/// Smart action cards guiding officers on the next recommended interactions.
class BorrowerRecommendedActions extends StatelessWidget {
  final Borrower borrower;
  final String? activeLoanId;

  const BorrowerRecommendedActions({
    super.key,
    required this.borrower,
    this.activeLoanId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recommended Officer Next Actions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (activeLoanId != null)
                  FilledButton.icon(
                    onPressed: () =>
                        context.push('/loans/$activeLoanId/payments'),
                    icon: const Icon(Icons.point_of_sale_outlined, size: 16),
                    label: const Text('Collect Payment'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                  ),
                FilledButton.tonalIcon(
                  onPressed: () => context.push(
                    '/borrowers/${borrower.id}/loans/new',
                    extra: borrower,
                  ),
                  icon: const Icon(Icons.add_card_outlined, size: 16),
                  label: const Text('Create New Loan'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('SMS payment reminder sent to borrower'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.sms_outlined, size: 16),
                  label: const Text('Send Reminder'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Field collection visit scheduled'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.pin_drop_outlined, size: 16),
                  label: const Text('Schedule Field Visit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
