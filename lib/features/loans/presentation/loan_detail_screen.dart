import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/installment.dart';
import '../domain/models/loan.dart';
import 'providers/loans_provider.dart';

/// Displays backend-owned loan totals and the persisted installment schedule.
class LoanDetailScreen extends ConsumerWidget {
  const LoanDetailScreen({super.key, required this.loanId, this.initialLoan});

  final String loanId;
  final Loan? initialLoan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(loanDetailProvider(loanId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh loan',
            onPressed: () => ref.invalidate(loanDetailProvider(loanId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: detail.when(
        loading: () => initialLoan == null
            ? const Center(child: CircularProgressIndicator())
            : _LoanContent(
                loan: initialLoan!,
                onRecordPayment: () => context.push('/loans/$loanId/payments'),
              ),
        error: (Object error, StackTrace stackTrace) => initialLoan == null
            ? Center(child: Text('Could not load loan: $error'))
            : _LoanContent(
                loan: initialLoan!,
                onRecordPayment: () => context.push('/loans/$loanId/payments'),
              ),
        data: (Loan loan) => _LoanContent(
          loan: loan,
          onRecordPayment: () => context.push('/loans/$loanId/payments'),
        ),
      ),
    );
  }
}

class _LoanContent extends StatelessWidget {
  const _LoanContent({required this.loan, required this.onRecordPayment});

  final Loan loan;
  final VoidCallback onRecordPayment;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  loan.status,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  label: 'Original principal',
                  value: loan.originalPrincipal,
                ),
                _SummaryRow(
                  label: 'Outstanding principal',
                  value: loan.outstandingPrincipal,
                ),
                _SummaryRow(label: 'Monthly rate', value: loan.monthlyRate),
                _SummaryRow(
                  label: 'Payment frequency',
                  value: loan.paymentsPerMonth == 1
                      ? 'Once a month'
                      : '${loan.paymentsPerMonth} times a month',
                ),
                _SummaryRow(label: 'First due date', value: loan.firstDueDate),
                _SummaryRow(label: 'Final due date', value: loan.finalDueDate),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: loan.status == 'Active' || loan.status == 'Overdue'
              ? onRecordPayment
              : null,
          icon: const Icon(Icons.add_card),
          label: const Text('Record Payment'),
        ),
        const SizedBox(height: 16),
        Text(
          'Installment Schedule',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (loan.installments.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No installment schedule was returned.'),
            ),
          )
        else
          ...loan.installments.map(
            (Installment installment) => Card(
              child: ExpansionTile(
                title: Text(
                  'Payment ${installment.installmentNumber} · '
                  '${installment.expectedPayment}',
                ),
                subtitle: Text(
                  '${installment.dueDate} · ${installment.status}',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _SummaryRow(
                    label: 'Interest',
                    value: installment.expectedInterest,
                  ),
                  _SummaryRow(
                    label: 'Principal',
                    value: installment.expectedPrincipal,
                  ),
                  _SummaryRow(
                    label: 'Remaining principal',
                    value: installment.expectedRemainingPrincipal,
                  ),
                  _SummaryRow(label: 'Paid', value: installment.paidAmount),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
