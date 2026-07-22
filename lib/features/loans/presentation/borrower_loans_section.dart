import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../borrowers/domain/borrower_model.dart';
import '../domain/models/loan.dart';
import 'providers/loans_provider.dart';

/// Displays backend loan accounts belonging to one existing borrower.
class BorrowerLoansSection extends ConsumerWidget {
  const BorrowerLoansSection({super.key, required this.borrower});

  final Borrower borrower;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loans = ref.watch(borrowerLoansProvider(borrower.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Loans',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Refresh loans',
              onPressed: () =>
                  ref.invalidate(borrowerLoansProvider(borrower.id)),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        loans.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (Object error, StackTrace stackTrace) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  Text('Could not load loans: $error'),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(borrowerLoansProvider(borrower.id)),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
          data: (List<Loan> items) {
            if (items.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No loans for this borrower yet.'),
                ),
              );
            }
            return Column(
              children: items
                  .map(
                    (Loan loan) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.account_balance_wallet),
                        title: Text(formatCurrency(loan.originalPrincipal)),
                        subtitle: Text(
                          '${loan.status} · ${loan.numberOfPayments} payments · '
                          'Rate ${formatInterestRate(loan.monthlyRate)} / mo',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/loans/${loan.id}'),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}
