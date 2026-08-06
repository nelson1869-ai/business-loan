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

/// Online-only controls for the backend-owned draft loan lifecycle.
class LoanWorkflowActions extends ConsumerWidget {
  const LoanWorkflowActions({required this.loan, super.key});

  final Loan loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loan.status != 'Draft') return const SizedBox.shrink();
    final session = ref.watch(officerSessionProvider).valueOrNull;
    final online = ref.watch(backendOnlineProvider);
    final maker = session?.userId == loan.createdByUserId;
    Widget? action;
    if (loan.approvedAt == null &&
        maker &&
        session?.can('loan.create') == true) {
      action = FilledButton(
        onPressed: online ? () => _requestApproval(context, ref) : null,
        child: const Text('Request Approval'),
      );
    } else if (loan.approvedAt != null &&
        loan.disbursedAt == null &&
        session?.can('loan.disburse') == true) {
      action = FilledButton(
        onPressed: online ? () => _transition(context, ref, 'disburse') : null,
        child: const Text('Disburse'),
      );
    } else if (loan.disbursedAt != null &&
        loan.activatedAt == null &&
        session?.can('loan.disburse') == true) {
      action = FilledButton(
        onPressed: online ? () => _transition(context, ref, 'activate') : null,
        child: const Text('Activate'),
      );
    }
    final status = loan.approvedAt == null
        ? 'Draft awaiting independent approval'
        : loan.disbursedAt == null
        ? 'Approved; awaiting disbursement'
        : 'Disbursed; awaiting activation';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.account_tree_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(status)),
            ?action,
          ],
        ),
      ),
    );
  }

  Future<void> _requestApproval(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(approvalRepositoryProvider)
          .create(
            action: 'loan.approve',
            entityType: 'loan',
            entityId: loan.id,
            reason: 'Approve draft loan for disbursement',
          );
      ref.invalidate(approvalsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Approval request submitted.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _transition(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final title = action == 'disburse' ? 'Release Loan Funds' : 'Activate Loan';
    final confirm = await ref
        .read(securityConfirmationServiceProvider)
        .promptAdminConfirmation(
          context,
          title: title,
          description:
              'Confirm critical action: $action for Loan #${loan.id.substring(0, 8)} (₱${loan.originalPrincipal})',
          confirmLabel: 'Confirm & Release',
        );
    if (!confirm || !context.mounted) return;

    try {
      await ref.read(remoteLoanRepositoryProvider).transition(loan.id, action);
      ref.invalidate(loanDetailProvider(loan.id));
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  void _showError(BuildContext context, Object error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ApiErrorMapper.message(error))));
  }
}
