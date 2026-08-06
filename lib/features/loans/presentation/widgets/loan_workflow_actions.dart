import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/security/officer_session.dart';
import '../../../../core/security/security_confirmation_service.dart';
import '../../../../core/widgets/online_required_banner.dart';
import '../../../approvals/data/approval_repository.dart';
import '../../../approvals/presentation/approval_provider.dart';
import '../../data/repositories/remote_loan_repository.dart';
import '../../domain/models/loan.dart';
import '../providers/loans_provider.dart';

/// Single-owner controls for loan lifecycle (Approve & Activate, Disburse, etc.).
class LoanWorkflowActions extends ConsumerWidget {
  const LoanWorkflowActions({required this.loan, super.key});

  final Loan loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide entirely for terminal states
    if (loan.status == 'Active' ||
        loan.status == 'Paid' ||
        loan.status == 'Closed' ||
        loan.status == 'Cancelled' ||
        loan.status == 'Defaulted') {
      return const SizedBox.shrink();
    }

    final session = ref.watch(officerSessionProvider).valueOrNull;
    final online = ref.watch(backendOnlineProvider);
    final isAdmin =
        session?.role == 'admin' || session?.role == 'owner';
    final canApprove = isAdmin || session?.can('loan.approve') == true;

    // ── DRAFT → not yet approved ──────────────────────────────────────────
    if (loan.status == 'Draft' && loan.approvedAt == null) {
      return _ActionCard(
        statusText: 'Draft — pending approval',
        children: [
          if (!isAdmin)
            // Officers: can only request via Inbox
            OutlinedButton.icon(
              onPressed: online ? () => _requestApproval(context, ref) : null,
              icon: const Icon(Icons.move_to_inbox, size: 15),
              label: const Text('Send to Inbox'),
            ),
          if (isAdmin) ...[
            // Admin/Owner: can request via Inbox OR approve immediately
            OutlinedButton.icon(
              onPressed: online ? () => _requestApproval(context, ref) : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
              icon: const Icon(Icons.move_to_inbox, size: 15),
              label: const Text('Send to Inbox'),
            ),
            FilledButton.icon(
              // Single-owner: approve + disburse + activate in ONE tap
              onPressed: online && canApprove
                  ? () => _approveAndActivate(context, ref)
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.rocket_launch_outlined, size: 17),
              label: const Text('Approve & Activate'),
            ),
          ],
        ],
      );
    }

    // ── DRAFT → approved but not disbursed ───────────────────────────────
    if (loan.status == 'Draft' && loan.approvedAt != null && loan.disbursedAt == null) {
      return _ActionCard(
        statusText: 'Approved — ready for disbursement',
        children: [
          FilledButton.icon(
            onPressed: online && canApprove
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
            onPressed: online && canApprove
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

  Future<void> _approveAndActivate(BuildContext context, WidgetRef ref) async {
    final confirm = await ref
        .read(securityConfirmationServiceProvider)
        .promptAdminConfirmation(
          context,
          title: 'Approve & Activate Loan',
          description:
              'This will approve, disburse, and activate Loan #${loan.id.substring(0, 8)} (₱${loan.originalPrincipal}) in one step.',
          confirmLabel: 'Approve & Activate',
        );
    if (!confirm || !context.mounted) return;

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

  Future<void> _requestApproval(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(approvalRepositoryProvider).create(
            action: 'loan.approve',
            entityType: 'loan',
            entityId: loan.id,
            reason: 'Approve draft loan for disbursement',
          );
      ref.invalidate(approvalsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Approval request sent to Inbox.')),
        );
      }
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
              'Confirm $action for Loan #${loan.id.substring(0, 8)} (₱${loan.originalPrincipal})',
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
