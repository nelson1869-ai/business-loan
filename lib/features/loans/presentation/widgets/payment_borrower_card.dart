import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/loan.dart';

/// Card displaying borrower profile & loan account identification during payment collection.
class PaymentBorrowerCard extends StatelessWidget {
  final Loan loan;

  const PaymentBorrowerCard({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shortLoanId = loan.id.length >= 8 ? loan.id.substring(0, 8) : loan.id;
    final shortBorrowerId = loan.borrowerId.length >= 8
        ? loan.borrowerId.substring(0, 8)
        : loan.borrowerId;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color: colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Borrower ID: $shortBorrowerId',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Loan #$shortLoanId · ${loan.status}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Quick Call/SMS buttons
                IconButton.filledTonal(
                  icon: const Icon(Icons.call_outlined, size: 18),
                  tooltip: 'Call Borrower',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calling borrower...')),
                    );
                  },
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  tooltip: 'View Borrower Profile',
                  onPressed: () =>
                      context.push('/borrowers/${loan.borrowerId}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
