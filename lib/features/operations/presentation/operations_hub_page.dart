import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/officer_session.dart';
import '../../../core/widgets/online_required_banner.dart';

/// Permission-aware entry point for online operational controls.
class OperationsHubPage extends ConsumerWidget {
  const OperationsHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(officerSessionProvider).valueOrNull;
    final items = <_OperationItem>[
      if (session?.can('borrower_registration.review') == true)
        const _OperationItem(
          'Pending Borrower Registrations',
          'Review and explicitly link portal access requests',
          Icons.person_search_outlined,
          '/operations/borrower-registrations',
        ),
      if (session?.can('policy.create') == true ||
          session?.can('policy.approve') == true)
        const _OperationItem(
          'Loan Policies',
          'Versioned drafts, activation, retirement, and history',
          Icons.policy_outlined,
          '/operations/policies',
        ),
      if (session?.permissions.any(_approvalPermission) == true)
        const _OperationItem(
          'Approval Inbox',
          'Review maker-checker requests',
          Icons.approval_outlined,
          '/operations/approvals',
        ),
      if (session?.can('reconciliation.submit') == true ||
          session?.can('reconciliation.approve') == true)
        const _OperationItem(
          'Collection Sessions',
          'Cash session submission and reconciliation',
          Icons.point_of_sale_outlined,
          '/operations/collections',
        ),
      if (session?.can('accounting.view') == true)
        const _OperationItem(
          'Accounting Journals',
          'Read-only immutable journal entries',
          Icons.menu_book_outlined,
          '/operations/accounting',
        ),
      if (session?.can('report.view') == true)
        const _OperationItem(
          'Operational Reports',
          'Portfolio risk, cash, variance, and trial balance',
          Icons.analytics_outlined,
          '/operations/reports',
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Operations')),
      body: Column(
        children: [
          const OnlineRequiredBanner(),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text('No operational permissions assigned.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(item.icon),
                          title: Text(item.title),
                          subtitle: Text(item.subtitle),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(item.route),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

bool _approvalPermission(String permission) => const {
  'loan.approve',
  'loan.disburse',
  'loan.restructure',
  'loan.write_off',
  'payment.reverse',
  'policy.approve',
  'reconciliation.approve',
  'accounting.post_adjustment',
}.contains(permission);

class _OperationItem {
  const _OperationItem(this.title, this.subtitle, this.icon, this.route);

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}
