import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/presentation/design_system/app_state_views.dart';
import '../../../core/security/officer_session.dart';
import '../../../core/widgets/online_required_banner.dart';
import '../data/approval_repository.dart';
import '../domain/approval_request.dart';
import 'approval_provider.dart';
import '../../loans/data/repositories/remote_loan_repository.dart';

/// Online-only maker-checker approval inbox.
class ApprovalInboxPage extends ConsumerWidget {
  const ApprovalInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(approvalsProvider);
    final session = ref.watch(officerSessionProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Approval Inbox')),
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
                  if (items.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: AppEmptyState(
                          icon: Icons.fact_check_outlined,
                          title: 'No approval requests',
                          description:
                              'Pending maker-checker requests will appear here when another officer needs your review.',
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
                        final selfApproval =
                            request.makerUserId == session?.userId;
                        return Card(
                          child: ListTile(
                            title: Text(request.action),
                            subtitle: Text(
                              '${request.entityType} • ${request.status}\n'
                              '${request.requestReason}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
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
                },
              ),
            ),
          ],
        ),
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
                Text('Entity: ${request.entityType} / ${request.entityId}'),
                const SizedBox(height: 8),
                Text('Maker reason: ${request.requestReason}'),
                const SizedBox(height: 12),
                if (selfApproval)
                  const Text(
                    'You created this request and cannot approve or reject it.',
                  )
                else if (request.status == 'pending')
                  TextField(
                    minLines: 2,
                    maxLines: 4,
                    enabled: !submitting,
                    onChanged: (value) => reason = value,
                    decoration: const InputDecoration(
                      labelText: 'Decision reason',
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
            if (!selfApproval && request.status == 'pending') ...[
              TextButton(
                onPressed: online && !submitting
                    ? () async {
                        setDialogState(() => submitting = true);
                        final success = await _decide(
                          dialogContext,
                          ref,
                          request.id,
                          'rejected',
                          reason,
                        );
                        if (success && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        } else if (dialogContext.mounted) {
                          setDialogState(() => submitting = false);
                        }
                      }
                    : null,
                child: const Text('Reject'),
              ),
              FilledButton(
                onPressed: online && !submitting
                    ? () async {
                        setDialogState(() => submitting = true);
                        final success = await _decide(
                          dialogContext,
                          ref,
                          request.id,
                          'approved',
                          reason,
                        );
                        if (success && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        } else if (dialogContext.mounted) {
                          setDialogState(() => submitting = false);
                        }
                      }
                    : null,
                child: const Text('Approve'),
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
    String id,
    String decision,
    String reason,
  ) async {
    if (reason.trim().length < 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a decision reason.')));
      return false;
    }
    try {
      final request = await ref
          .read(approvalRepositoryProvider)
          .decide(requestId: id, decision: decision, reason: reason.trim());
      if (decision == 'approved' && request.action == 'loan.approve') {
        await ref
            .read(remoteLoanRepositoryProvider)
            .transition(request.entityId, 'approve');
      }
      ref.invalidate(approvalsProvider);
      return true;
    } catch (error) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ApiErrorMapper.message(error))));
      return false;
    }
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
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
