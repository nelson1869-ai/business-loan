import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/borrower_model.dart';

class BorrowerActionButtons extends StatelessWidget {
  const BorrowerActionButtons({super.key, required this.borrower});

  final Borrower borrower;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push(
              '/borrowers/${borrower.id}/loans/new',
              extra: borrower,
            ),
            icon: const Icon(Icons.add_card, size: 18),
            label: const Text('New Loan'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                context.push('/borrowers/register', extra: borrower),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
        ),
      ],
    );
  }
}
