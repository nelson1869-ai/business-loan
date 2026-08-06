import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/presentation/design_system/app_state_views.dart';
import '../../../core/security/officer_session.dart';
import '../../../core/security/security_confirmation_service.dart';
import '../../../core/widgets/online_required_banner.dart';
import '../data/approval_repository.dart';
import '../domain/approval_request.dart';
import 'approval_provider.dart';
import '../../loans/data/repositories/remote_loan_repository.dart';
import '../../loans/presentation/providers/loans_provider.dart';

/// Single-owner Admin Confirmations & Approval Page with Tabbed Filtering.
class ApprovalInboxPage extends ConsumerWidget {
  const ApprovalInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(approvalsProvider);
    final session = ref.watch(officerSessionProvider).valueOrNull;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Approval Inbox'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.pending_actions), text: 'Pending'),
              Tab(icon: Icon(Icons.history), text: 'History'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              const OnlineRequiredBanner(),
              Expanded(
                child: requests.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _Retry(
                    message: ApiErrorMapper.message(error),
                    onRetry: () => ref.invalidate(approvalsProvider),
                  ),
                  data: (items) {
                    final pendingItems = items.where((a) => a.status == 'pending').toList();
                    final historyItems = items.where((a) => a.status != 'pending').toList();

                    return TabBarView(
                      children: [
                        // Tab 1: Pending Requests
                        _buildRequestList(
                          context,
                          ref,
                          pendingItems,
                          session?.userId,
                          emptyTitle: 'No Pending Approvals',
                          emptyDescription: 'All loan and action requests have been reviewed.',
                        ),

                        // Tab 2: Approval History
                        _buildRequestList(
                          context,
                          ref,
                          historyItems,
                          session?.userId,
                          emptyTitle: 'No Approval History',
                          emptyDescription: 'Completed review records will appear here.',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestList(
    BuildContext context,
    WidgetRef ref,
    List<ApprovalRequest> items,
    String? currentUserId, {
    required String emptyTitle,
    required String emptyDescription,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppEmptyState(
            icon: Icons.fact_check_outlined,
            title: emptyTitle,
            description: emptyDescription,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(approvalsProvider.future),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final request = items[index];
          final selfApproval = request.makerUserId == currentUserId;
          final isPending = request.status == 'pending';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Row(
                children: [
                  Text(
                    request.action,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  _StatusChip(status: request.status),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${request.entityType.toUpperCase()} • #${request.entityId.substring(0, request.entityId.length > 8 ? 8 : request.entityId.length)}\n'
                  'Reason: ${request.requestReason}',
                ),
              ),
              isThreeLine: true,
              trailing: Icon(
                isPending ? Icons.edit_note_rounded : Icons.chevron_right,
                color: isPending ? Theme.of(context).colorScheme.primary : Colors.grey,
              ),
              onTap: () => _showDetails(
                context,
                ref,
                request,
                selfApproval,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    WidgetRef ref,
    ApprovalRequest request,
    bool selfApproval,
  ) async {
    final online = ref.read(backendOnlineProvider);
    var reason = '';
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(request.action),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Entity: ${request.entityType.toUpperCase()} / #${request.entityId}'),
                const SizedBox(height: 8),
                Text('Status: ${request.status.toUpperCase()}'),
                const SizedBox(height: 8),
                Text('Maker Reason: ${request.requestReason}'),
                const SizedBox(height: 12),
                if (request.status == 'pending')
                  TextField(
                    minLines: 2,
                    maxLines: 4,
                    enabled: !submitting,
                    onChanged: (value) => reason = value,
                    decoration: const InputDecoration(
                      labelText: 'Decision reason / Owner note',
                      hintText: 'Enter reason or note (optional)',
                    ),
                  ),
                if (submitting) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            if (request.status == 'pending') ...[
              TextButton(
                onPressed: online && !submitting
                    ? () async {
                        final confirm = await ref
                            .read(securityConfirmationServiceProvider)
                            .promptAdminConfirmation(
                              dialogContext,
                              title: 'Reject Request',
                              description:
                                  'Confirm rejection of ${request.action} (${request.entityType})',
                              confirmLabel: 'Reject Request',
                            );
                        if (!confirm || !dialogContext.mounted) return;

                        setDialogState(() => submitting = true);
                        final success = await _decide(
                          dialogContext,
                          ref,
                          request,
                          'rejected',
                          reason.isEmpty ? 'Owner rejected' : reason,
                        );
                        if (success && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        } else if (dialogContext.mounted) {
                          setDialogState(() => submitting = false);
                        }
                      }
                    : null,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Reject'),
              ),
              FilledButton(
                onPressed: online && !submitting
                    ? () async {
                        final confirm = await ref
                            .read(securityConfirmationServiceProvider)
                            .promptAdminConfirmation(
                              dialogContext,
                              title: 'Approve Request',
                              description:
                                  'Confirm approval of ${request.action} (${request.entityType})',
                              confirmLabel: 'Approve & Execute',
                            );
                        if (!confirm || !dialogContext.mounted) return;

                        setDialogState(() => submitting = true);
                        final success = await _decide(
                          dialogContext,
                          ref,
                          request,
                          'approved',
                          reason.isEmpty ? 'Owner approved' : reason,
                        );
                        if (success && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        } else if (dialogContext.mounted) {
                          setDialogState(() => submitting = false);
                        }
                      }
                    : null,
                child: const Text('Approve & Execute'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool> _decide(
    BuildContext context,
    WidgetRef ref,
    ApprovalRequest request,
    String decision,
    String reason,
  ) async {
    if (reason.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a decision reason.')),
      );
      return false;
    }
    try {
      final updatedRequest = await ref
          .read(approvalRepositoryProvider)
          .decide(requestId: request.id, decision: decision, reason: reason.trim());

      if (decision == 'approved' && updatedRequest.action == 'loan.approve') {
        try {
          await ref
              .read(remoteLoanRepositoryProvider)
              .transition(updatedRequest.entityId, 'approve');
        } catch (_) {
          // Ignore if loan was already transitioned
        }
        ref.invalidate(loanDetailProvider(updatedRequest.entityId));
        ref.invalidate(allLoansProvider);
      }

      ref.invalidate(approvalsProvider);
      return true;
    } catch (error) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorMapper.message(error))),
      );
      return false;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status.toLowerCase()) {
      case 'pending':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      case 'approved':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        break;
      case 'rejected':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
