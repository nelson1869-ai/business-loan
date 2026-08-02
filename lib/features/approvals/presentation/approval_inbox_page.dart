import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/security/officer_session.dart';
import '../../../core/widgets/online_required_banner.dart';
import '../data/approval_repository.dart';
import '../domain/approval_request.dart';
import 'approval_provider.dart';

/// Online-only maker-checker approval inbox.
class ApprovalInboxPage extends ConsumerWidget {
  const ApprovalInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(approvalsProvider);
    final session = ref.watch(officerSessionProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Approval Inbox')),
      body: Column(
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
                  return const Center(child: Text('No approval requests.'));
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
                          onTap: () =>
                              _showDetails(context, ref, request, selfApproval),
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
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    WidgetRef ref,
    ApprovalRequest request,
    bool selfApproval,
  ) async {
    final online = ref.read(backendOnlineProvider);
    final reason = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                  controller: reason,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Decision reason',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (!selfApproval && request.status == 'pending') ...[
            TextButton(
              onPressed: online
                  ? () => _decide(
                      dialogContext,
                      ref,
                      request.id,
                      'rejected',
                      reason.text,
                    )
                  : null,
              child: const Text('Reject'),
            ),
            FilledButton(
              onPressed: online
                  ? () => _decide(
                      dialogContext,
                      ref,
                      request.id,
                      'approved',
                      reason.text,
                    )
                  : null,
              child: const Text('Approve'),
            ),
          ],
        ],
      ),
    );
    reason.dispose();
  }

  Future<void> _decide(
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
      return;
    }
    try {
      await ref
          .read(approvalRepositoryProvider)
          .decide(requestId: id, decision: decision, reason: reason.trim());
      ref.invalidate(approvalsProvider);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ApiErrorMapper.message(error))));
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
