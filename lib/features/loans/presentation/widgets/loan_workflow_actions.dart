import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/security/officer_session.dart';
import '../../../../core/security/security_confirmation_service.dart';
import '../../../../core/widgets/online_required_banner.dart';
import '../../../borrowers/data/borrower_repository.dart';
import '../../../borrowers/domain/borrower_model.dart';
import '../../data/repositories/remote_loan_repository.dart';
import '../../domain/models/loan.dart';
import '../providers/loans_provider.dart';

/// Single-owner controls for loan lifecycle (Approve & Activate, Disburse, etc.).
class LoanWorkflowActions extends ConsumerWidget {
  const LoanWorkflowActions({required this.loan, super.key});

  final Loan loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide entirely for terminal / active states
    if (loan.status == 'Active' ||
        loan.status == 'Paid' ||
        loan.status == 'Closed' ||
        loan.status == 'Cancelled' ||
        loan.status == 'Defaulted') {
      return const SizedBox.shrink();
    }

    final session = ref.watch(officerSessionProvider).valueOrNull;
    final online = ref.watch(backendOnlineProvider);
    final canManage = session?.can('loan.approve') == true ||
        session?.can('loan.create') == true ||
        session?.role == 'admin' ||
        session?.role == 'owner';

    // ── DRAFT LOAN ──────────────────────────────────────────────────────────
    if (loan.status == 'Draft' && loan.approvedAt == null) {
      return _ActionCard(
        statusText: 'Draft Loan — Awaiting Owner Approval',
        children: [
          OutlinedButton.icon(
            onPressed: online && canManage ? () => _cancelDraft(context, ref) : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 15),
            label: const Text('Cancel Draft'),
          ),
          FilledButton.icon(
            onPressed: online && canManage
                ? () => _promptApproveAndActivate(context, ref)
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.rocket_launch_outlined, size: 17),
            label: const Text('APPROVE & ACTIVATE'),
          ),
        ],
      );
    }

    // ── DRAFT → approved but not disbursed ───────────────────────────────
    if (loan.status == 'Draft' && loan.approvedAt != null && loan.disbursedAt == null) {
      return _ActionCard(
        statusText: 'Approved — ready for disbursement',
        children: [
          FilledButton.icon(
            onPressed: online && canManage
                ? () => _transition(context, ref, 'disburse',
                    title: 'Disburse Funds',
                    label: 'Release Funds')
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.payments_outlined, size: 17),
            label: const Text('Disburse Funds'),
          ),
        ],
      );
    }

    // ── DRAFT → disbursed but not activated ──────────────────────────────
    if (loan.status == 'Draft' && loan.disbursedAt != null && loan.activatedAt == null) {
      return _ActionCard(
        statusText: 'Disbursed — ready for activation',
        children: [
          FilledButton.icon(
            onPressed: online && canManage
                ? () => _transition(context, ref, 'activate',
                    title: 'Activate Loan',
                    label: 'Activate')
                : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.bolt, size: 17),
            label: const Text('Activate Schedule'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _promptApproveAndActivate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Fetch borrower details for rich single-owner confirmation
    Borrower? borrower;
    try {
      borrower = await ref
          .read(borrowerRepositoryProvider)
          .getBorrower(loan.borrowerId);
    } catch (_) {}

    if (!context.mounted) return;

    final borrowerName = borrower != null
        ? '${borrower.firstName} ${borrower.lastName}'
        : 'Borrower ID: ${loan.borrowerId.substring(0, loan.borrowerId.length > 8 ? 8 : loan.borrowerId.length)}';

    final double rate = double.tryParse(loan.monthlyRate) ?? 0.0;
    final String rateStr = (rate * 100).toStringAsFixed(2);
    final double regularPayment =
        double.tryParse(loan.regularPaymentAmount) ?? 0.0;
    final double totalRepayment = regularPayment * loan.numberOfPayments;

    // Show detailed loan review modal
    final shouldProceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SingleOwnerReviewDialog(
        loan: loan,
        borrowerName: borrowerName,
        monthlyRatePercent: rateStr,
        totalRepayment: totalRepayment.toStringAsFixed(2),
      ),
    );

    if (shouldProceed != true || !context.mounted) return;

    // PIN / Biometric Confirmation
    final confirmed = await ref
        .read(securityConfirmationServiceProvider)
        .promptAdminConfirmation(
          context,
          title: 'Confirm Loan Activation',
          description:
              'Approve and activate Loan #${loan.id.substring(0, loan.id.length > 8 ? 8 : loan.id.length)} for $borrowerName (₱${loan.originalPrincipal})',
          confirmLabel: 'Confirm & Activate',
        );

    if (!confirmed || !context.mounted) return;

    try {
      await ref
          .read(remoteLoanRepositoryProvider)
          .transition(loan.id, 'approve_and_activate');
      ref.invalidate(loanDetailProvider(loan.id));
      ref.invalidate(allLoansProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loan approved and activated successfully!'),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _cancelDraft(BuildContext context, WidgetRef ref) async {
    final confirm = await ref
        .read(securityConfirmationServiceProvider)
        .promptAdminConfirmation(
          context,
          title: 'Cancel Draft Loan',
          description:
              'Are you sure you want to cancel this draft loan application?',
          confirmLabel: 'Cancel Loan',
        );
    if (!confirm || !context.mounted) return;

    try {
      await ref.read(remoteLoanRepositoryProvider).transition(loan.id, 'cancel');
      ref.invalidate(loanDetailProvider(loan.id));
      ref.invalidate(allLoansProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _transition(
    BuildContext context,
    WidgetRef ref,
    String action, {
    required String title,
    required String label,
  }) async {
    final confirm = await ref
        .read(securityConfirmationServiceProvider)
        .promptAdminConfirmation(
          context,
          title: title,
          description:
              'Confirm $action for Loan #${loan.id.substring(0, loan.id.length > 8 ? 8 : loan.id.length)} (₱${loan.originalPrincipal})',
          confirmLabel: label,
        );
    if (!confirm || !context.mounted) return;

    try {
      await ref.read(remoteLoanRepositoryProvider).transition(loan.id, action);
      ref.invalidate(loanDetailProvider(loan.id));
      ref.invalidate(allLoansProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _showError(BuildContext context, Object error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ApiErrorMapper.message(error))),
    );
  }
}

// ── Single Owner Review Confirmation Dialog ─────────────────────────────────

class _SingleOwnerReviewDialog extends StatelessWidget {
  const _SingleOwnerReviewDialog({
    required this.loan,
    required this.borrowerName,
    required this.monthlyRatePercent,
    required this.totalRepayment,
  });

  final Loan loan;
  final String borrowerName;
  final String monthlyRatePercent;
  final String totalRepayment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_outlined,
              color: Color(0xFF0D9488),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Approve & Activate',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review loan terms before single-owner activation:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            _detailRow('Borrower', borrowerName, isHighlight: true),
            const Divider(height: 16),
            _detailRow('Principal', '₱${loan.originalPrincipal}', isHighlight: true),
            _detailRow('Interest Rate', '$monthlyRatePercent% / month'),
            _detailRow(
              'Loan Term',
              '${loan.termMonths} months (${loan.numberOfPayments} payments)',
            ),
            _detailRow('Installment Amount', '₱${loan.regularPaymentAmount}'),
            _detailRow('Total Repayment', '₱$totalRepayment', isHighlight: true),
            _detailRow('First Due Date', loan.firstDueDate),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Back'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0D9488),
          ),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Proceed to PIN'),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isHighlight ? Colors.white : Colors.white70,
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                color: isHighlight ? const Color(0xFF10B981) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared card shell ───────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.statusText, required this.children});

  final String statusText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
