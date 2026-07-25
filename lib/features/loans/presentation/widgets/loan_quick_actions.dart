import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/loan.dart';

/// Quick Actions Bar for Loan Details.
class LoanQuickActions extends StatelessWidget {
  final Loan loan;
  final VoidCallback onShare;
  final VoidCallback? onReversePayment;

  const LoanQuickActions({
    super.key,
    required this.loan,
    required this.onShare,
    this.onReversePayment,
  });

  @override
  Widget build(BuildContext context) {
    final canPay = loan.status == 'Active' || loan.status == 'Overdue';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canPay)
          FilledButton.icon(
            onPressed: () => context.push('/loans/${loan.id}/payments'),
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text('Record Payment'),
          ),
        FilledButton.tonalIcon(
          onPressed: onShare,
          icon: const Icon(Icons.share_outlined, size: 18),
          label: const Text('Share Schedule'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Generating printable PDF receipt...'),
              ),
            );
          },
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Print Receipt'),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (val) {
            if (val == 'reverse' && onReversePayment != null) {
              onReversePayment!();
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'reverse',
              child: Row(
                children: [
                  Icon(Icons.undo, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Text('Reverse Payment'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
