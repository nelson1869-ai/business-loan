import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../borrower_communication/presentation/borrower_communication_provider.dart';
import '../../borrower_communication/presentation/send_to_borrower_sheet.dart';
import '../data/models/loan_explanation.dart';
import '../data/repositories/remote_loan_repository.dart';
import '../domain/models/loan.dart';
import 'providers/loans_provider.dart';
import 'widgets/loan_header_card.dart';
import 'widgets/loan_payment_status_banner.dart';
import 'widgets/loan_quick_actions.dart';
import 'widgets/loan_skeleton_loader.dart';
import 'widgets/loan_workflow_actions.dart';
import 'widgets/tabs/loan_activity_tab.dart';
import 'widgets/tabs/loan_documents_tab.dart';
import 'widgets/tabs/loan_notes_tab.dart';
import 'widgets/tabs/loan_overview_tab.dart';
import 'widgets/tabs/loan_payments_tab.dart';
import 'widgets/tabs/loan_schedule_tab.dart';

/// Redesigned Material 3 Loan Detail Screen.
class LoanDetailScreen extends ConsumerWidget {
  const LoanDetailScreen({super.key, required this.loanId, this.initialLoan});

  final String loanId;
  final Loan? initialLoan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(loanDetailProvider(loanId));

    return DefaultTabController(
      length: 6,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/loans');
              }
            },
          ),
          title: const Text('Loan Details'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Send to borrower',
              icon: const Icon(Icons.send_to_mobile_outlined),
              onPressed: () => _sendToBorrower(context, ref),
            ),
            IconButton(
              tooltip: 'Refresh loan',
              onPressed: () => ref.invalidate(loanDetailProvider(loanId)),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: detail.when(
          loading: () => initialLoan == null
              ? const LoanSkeletonLoader()
              : _LoanDetailContent(
                  loan: initialLoan!,
                  onRecordPayment: () =>
                      context.push('/loans/$loanId/payments'),
                  onShareSchedule: () => _sendToBorrower(context, ref),
                  onExplain: () => _explainLoan(context, ref),
                ),
          error: (Object error, StackTrace stackTrace) => initialLoan == null
              ? Center(child: Text(ApiErrorMapper.message(error)))
              : _LoanDetailContent(
                  loan: initialLoan!,
                  onRecordPayment: () =>
                      context.push('/loans/$loanId/payments'),
                  onShareSchedule: () => _sendToBorrower(context, ref),
                  onExplain: () => _explainLoan(context, ref),
                ),
          data: (Loan loan) => _LoanDetailContent(
            loan: loan,
            onRecordPayment: () => context.push('/loans/$loanId/payments'),
            onShareSchedule: () => _sendToBorrower(context, ref),
            onExplain: () => _explainLoan(context, ref),
          ),
        ),
      ),
    );
  }

  Future<void> _sendToBorrower(BuildContext context, WidgetRef ref) async {
    final loan =
        ref.read(loanDetailProvider(loanId)).valueOrNull ?? initialLoan;
    if (loan == null || !context.mounted) return;
    await SendToBorrowerSheet.show(
      context,
      BorrowerCommunicationRequest(borrowerId: loan.borrowerId, loan: loan),
    );
  }

  Future<void> _explainLoan(BuildContext context, WidgetRef ref) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text(
              'Preparing a plain-language explanation…',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'The free AI service may take up to a minute.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
    try {
      final explanation = await ref
          .read(remoteLoanRepositoryProvider)
          .explainLoan(loanId);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _LoanExplanationSheet(explanation: explanation),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final message = error is RemoteLoanException
          ? error.message
          : ApiErrorMapper.message(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _LoanDetailContent extends StatelessWidget {
  final Loan loan;
  final VoidCallback onRecordPayment;
  final VoidCallback onShareSchedule;
  final VoidCallback onExplain;

  const _LoanDetailContent({
    required this.loan,
    required this.onRecordPayment,
    required this.onShareSchedule,
    required this.onExplain,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Loan Header Card
                  LoanHeaderCard(loan: loan),
                  LoanWorkflowActions(loan: loan),
                  const SizedBox(height: 12),
                  // Payment Status Banner (Overdue Alert / Healthy Status)
                  LoanPaymentStatusBanner(
                    loan: loan,
                    onPayNow: onRecordPayment,
                  ),
                  const SizedBox(height: 14),
                  // Quick Actions Bar
                  LoanQuickActions(
                    loan: loan,
                    onSendToBorrower: onShareSchedule,
                    onExplain: onExplain,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorColor: theme.colorScheme.primary,
                tabs: const [
                  Tab(text: 'Schedule'),
                  Tab(text: 'Overview'),
                  Tab(text: 'Payments'),
                  Tab(text: 'Documents'),
                  Tab(text: 'Notes'),
                  Tab(text: 'Activity'),
                ],
              ),
              theme.colorScheme.surface,
            ),
          ),
        ];
      },
      body: TabBarView(
        children: [
          LoanScheduleTab(loan: loan, onRecordPayment: onRecordPayment),
          LoanOverviewTab(loan: loan),
          LoanPaymentsTab(loan: loan),
          LoanDocumentsTab(borrowerId: loan.borrowerId, loanId: loan.id),
          LoanNotesTab(borrowerId: loan.borrowerId, loanId: loan.id),
          LoanActivityTab(loan: loan),
        ],
      ),
    );
  }
}

class _LoanExplanationSheet extends StatelessWidget {
  const _LoanExplanationSheet({required this.explanation});

  final LoanExplanation explanation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Loan Explanation',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(explanation.summary, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            ...explanation.keyPoints.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 6),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(point)),
                  ],
                ),
              ),
            ),
            const Divider(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    explanation.disclaimer,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
