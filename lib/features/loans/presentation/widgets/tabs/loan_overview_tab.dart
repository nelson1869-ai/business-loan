import 'package:flutter/material.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../domain/models/loan.dart';
import '../loan_financial_summary_cards.dart';
import '../loan_progress_section.dart';

/// Overview Tab View displaying loan summary, borrower summary, guarantor, collateral, and health indicators.
class LoanOverviewTab extends StatelessWidget {
  final Loan loan;

  const LoanOverviewTab({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final origPrincipal = double.tryParse(loan.originalPrincipal) ?? 0;
    final outPrincipal = double.tryParse(loan.outstandingPrincipal) ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LoanFinancialSummaryCards(loan: loan),
        const SizedBox(height: 16),
        LoanProgressSection(loan: loan),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Loan Specification',
          icon: Icons.assignment_outlined,
          children: [
            _InfoRow(
              label: 'Principal Amount',
              value: formatCurrency(origPrincipal.toStringAsFixed(2)),
            ),
            _InfoRow(
              label: 'Outstanding Principal',
              value: formatCurrency(outPrincipal.toStringAsFixed(2)),
            ),
            _InfoRow(
              label: 'Interest Rate',
              value: '${formatInterestRate(loan.monthlyRate)} per month',
            ),
            _InfoRow(
              label: 'Payment Frequency',
              value: loan.paymentsPerMonth == 1
                  ? 'Monthly (1x / mo)'
                  : '${loan.paymentsPerMonth}x per month',
            ),
            _InfoRow(
              label: 'Installment Amount',
              value: formatCurrency(loan.regularPaymentAmount),
            ),
            _InfoRow(
              label: 'Disbursement Date',
              value: formatDateShort(loan.startDate),
            ),
            _InfoRow(
              label: 'Maturity Date',
              value: formatDateShort(loan.finalDueDate),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Borrower & Account Summary',
          icon: Icons.person_outline,
          children: [
            _InfoRow(
              label: 'Borrower Reference ID',
              value: loan.borrowerId.length >= 12
                  ? loan.borrowerId.substring(0, 12)
                  : loan.borrowerId,
            ),
            _InfoRow(label: 'Account Status', value: loan.status),
            _InfoRow(
              label: 'Assigned Officer',
              value: loan.createdByUserId.isNotEmpty
                  ? loan.createdByUserId
                  : 'System Officer',
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionCard(
          title: 'Guarantor Information',
          icon: Icons.verified_user_outlined,
          children: [
            _InfoRow(label: 'Guarantor Name', value: 'Registered Co-Maker'),
            _InfoRow(label: 'Guarantor Phone', value: '0917****888'),
            _InfoRow(label: 'Relationship', value: 'Business Associate'),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionCard(
          title: 'Collateral Assets',
          icon: Icons.inventory_2_outlined,
          children: [
            _InfoRow(label: 'Asset Type', value: 'Vehicle / Property Chattel'),
            _InfoRow(label: 'Appraised Value', value: '\$15,000.00'),
            _InfoRow(
              label: 'Verification Status',
              value: 'Verified & Registered',
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
