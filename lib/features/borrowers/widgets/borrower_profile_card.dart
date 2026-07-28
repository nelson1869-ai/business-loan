import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../loans/domain/models/loan.dart';
import '../domain/borrower_model.dart';
import '../providers/borrowers_state.dart';
import 'pii_masked_text.dart';

class BorrowerProfileCard extends ConsumerWidget {
  const BorrowerProfileCard({
    super.key,
    required this.borrower,
    required this.loansAsync,
  });

  final Borrower borrower;
  final AsyncValue<List<Loan>> loansAsync;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusColor = switch (borrower.status.toLowerCase()) {
      'active' => Colors.green,
      'pending' => Colors.orange,
      _ => Colors.grey,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  child: Text(
                    _initials(borrower.fullName),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        borrower.fullName,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      PIIMaskedText(
                        icon: Icons.badge_outlined,
                        label: 'ID',
                        value: borrower.nationalId,
                      ),
                      PIIMaskedText(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: borrower.phone,
                        isPhone: true,
                      ),
                      _ProfileInfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'DOB: ${borrower.dateOfBirth}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: borrower.status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                  ],
                  onChanged: (newStatus) async {
                    if (newStatus != null && newStatus != borrower.status) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Change Borrower Status'),
                          content: Text(
                            'Change ${borrower.fullName}\'s status from "${borrower.status}" to "$newStatus"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Confirm'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        ref
                            .read(borrowersNotifierProvider.notifier)
                            .updateBorrower(
                              Borrower(
                                id: borrower.id,
                                firstName: borrower.firstName,
                                lastName: borrower.lastName,
                                nationalId: borrower.nationalId,
                                phone: borrower.phone,
                                dateOfBirth: borrower.dateOfBirth,
                                status: newStatus,
                                createdAt: borrower.createdAt,
                              ),
                            );
                      }
                    }
                  },
                ),
              ],
            ),
            loansAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(
                  child: SizedBox(
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Could not load loan data',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              data: (loans) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildFinancialSummary(loans, theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummary(List<Loan> loans, ThemeData theme) {
    double totalBorrowed = 0;
    double totalOutstanding = 0;
    int activeCount = 0;
    int paidCount = 0;
    double overdueAmount = 0;

    for (final loan in loans) {
      final principal = double.tryParse(loan.originalPrincipal) ?? 0;
      final outstanding = double.tryParse(loan.outstandingPrincipal) ?? 0;
      totalBorrowed += principal;
      if (loan.status == 'Active' || loan.status == 'Overdue') {
        activeCount++;
        totalOutstanding += outstanding;
        if (loan.status == 'Overdue') {
          overdueAmount += outstanding;
        }
      }
      if (loan.status == 'Paid') {
        paidCount++;
      }
    }

    return Column(
      children: [
        const Divider(height: 16),
        _MetricRow(
          label: 'Total Borrowed',
          value: formatCurrency(totalBorrowed.toStringAsFixed(2)),
        ),
        const Divider(height: 12),
        _MetricRow(
          label: 'Outstanding Balance',
          value: formatCurrency(totalOutstanding.toStringAsFixed(2)),
          isHighlight: true,
        ),
        const Divider(height: 12),
        _MetricRow(label: 'Active Loans', value: '$activeCount'),
        const Divider(height: 12),
        _MetricRow(label: 'Completed Loans', value: '$paidCount'),
        if (overdueAmount > 0) ...[
          const Divider(height: 12),
          _MetricRow(
            label: 'Overdue Amount',
            value: formatCurrency(overdueAmount.toStringAsFixed(2)),
            isError: true,
          ),
        ],
      ],
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.isError = false,
  });

  final String label;
  final String value;
  final bool isHighlight;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isHighlight || isError
                    ? FontWeight.bold
                    : FontWeight.w600,
                color: isError
                    ? Colors.red
                    : isHighlight
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
