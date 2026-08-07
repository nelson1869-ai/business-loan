import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/presentation/design_system/app_state_views.dart';
import '../../../core/security/officer_session.dart';
import '../../../core/widgets/online_required_banner.dart';
import '../data/loan_policy_repository.dart';
import '../domain/loan_policy.dart';
import 'loan_policy_provider.dart';

/// Versioned policy administration using backend-owned lifecycle rules.
class LoanPolicyPage extends ConsumerWidget {
  const LoanPolicyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(ownerSessionProvider).valueOrNull;
    final policies = ref.watch(loanPoliciesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Policies'),
        actions: [
          if (session?.can('policy.create') == true)
            IconButton(
              tooltip: 'Create draft policy',
              onPressed: ref.watch(backendOnlineProvider)
                  ? () => _createDraft(context, ref)
                  : null,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const OnlineRequiredBanner(),
            Expanded(
              child: policies.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: FilledButton.icon(
                    onPressed: () => ref.invalidate(loanPoliciesProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text(ApiErrorMapper.message(error)),
                  ),
                ),
                data: (items) => items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: AppEmptyState(
                            icon: Icons.policy_outlined,
                            title: 'No loan policies yet',
                            description:
                                'Create a draft policy to define versioned lending rules. A different authorized user must activate it.',
                            actionLabel:
                                session?.can('policy.create') == true &&
                                    ref.watch(backendOnlineProvider)
                                ? 'Create Draft'
                                : null,
                            onAction:
                                session?.can('policy.create') == true &&
                                    ref.watch(backendOnlineProvider)
                                ? () => _createDraft(context, ref)
                                : null,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.refresh(loanPoliciesProvider.future),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final policy = items[index];
                            return Card(
                              child: ListTile(
                                title: Text(
                                  '${policy.name} v${policy.version}',
                                ),
                                subtitle: Text(
                                  '${policy.status.toUpperCase()} • '
                                  '${policy.currency} • effective ${policy.effectiveDate}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () =>
                                    _details(context, ref, policy, session),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _details(
    BuildContext context,
    WidgetRef ref,
    LoanPolicy policy,
    OwnerSession? session,
  ) async {
    final reason = TextEditingController();
    final canApprove =
        session?.can('policy.approve') == true &&
        session?.userId != policy.createdByUserId &&
        ref.read(backendOnlineProvider);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${policy.name} v${policy.version}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${policy.status}'),
              Text('Method: ${policy.interestMethod}'),
              Text('Rate period: ${policy.ratePeriod}'),
              Text('Rate range: ${policy.minimumRate}–${policy.maximumRate}'),
              Text('Change reason: ${policy.changeReason}'),
              if (canApprove && policy.status != 'retired') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Decision reason',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (canApprove && policy.status == 'draft')
            FilledButton(
              onPressed: () => _policyDecision(
                dialogContext,
                ref,
                policy,
                reason.text,
                activate: true,
              ),
              child: const Text('Activate'),
            ),
          if (canApprove && policy.status == 'active')
            FilledButton(
              onPressed: () => _policyDecision(
                dialogContext,
                ref,
                policy,
                reason.text,
                activate: false,
              ),
              child: const Text('Retire'),
            ),
        ],
      ),
    );
    reason.dispose();
  }

  Future<void> _policyDecision(
    BuildContext context,
    WidgetRef ref,
    LoanPolicy policy,
    String reason, {
    required bool activate,
  }) async {
    if (reason.trim().isEmpty) return;
    try {
      final repository = ref.read(loanPolicyRepositoryProvider);
      if (activate) {
        await repository.activate(policy.id, reason.trim());
      } else {
        await repository.retire(policy.id, reason.trim());
      }
      ref.invalidate(loanPoliciesProvider);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ApiErrorMapper.message(error))));
    }
  }

  Future<void> _createDraft(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final version = TextEditingController(text: '1');
    final minRate = TextEditingController(text: '0.00');
    final maxRate = TextEditingController(text: '0.10');
    final reason = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create draft policy'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Policy name'),
              ),
              TextField(
                controller: version,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Version'),
              ),
              TextField(
                controller: minRate,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum decimal rate',
                ),
              ),
              TextField(
                controller: maxRate,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum decimal rate',
                ),
              ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Change reason'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Create Draft'),
          ),
        ],
      ),
    );
    if (created == true && context.mounted) {
      try {
        final now = DateTime.now();
        await ref.read(loanPolicyRepositoryProvider).createDraft({
          'policyName': name.text.trim(),
          'versionNumber': int.tryParse(version.text) ?? 1,
          'currency': 'PHP',
          'interestMethod': 'fixed_periodic_reducing_balance',
          'ratePeriod': 'monthly',
          'minimumRate': minRate.text.trim(),
          'maximumRate': maxRate.text.trim(),
          'roundingPolicy': {'mode': 'half_up', 'scale': 2},
          'paymentAllocationOrder': ['interest', 'principal', 'fees'],
          'gracePeriodConfiguration': {'days': 0},
          'lateFeeConfiguration': {'enabled': false},
          'earlySettlementConfiguration': {'enabled': true},
          'excessPaymentTreatment': {'mode': 'unapplied_credit'},
          'restructuringPolicy': {'enabled': false},
          'writeOffPolicy': {'enabled': false},
          'contractTemplateVersion': 'v1',
          'effectiveDate':
              '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          'changeReason': reason.text.trim(),
        });
        ref.invalidate(loanPoliciesProvider);
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiErrorMapper.message(error))));
      }
    }
    name.dispose();
    version.dispose();
    minRate.dispose();
    maxRate.dispose();
    reason.dispose();
  }
}
