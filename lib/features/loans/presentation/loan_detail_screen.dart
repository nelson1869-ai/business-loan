import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formatters.dart';
import '../domain/models/loan.dart';
import 'providers/loans_provider.dart';
import 'widgets/loan_header_card.dart';
import 'widgets/loan_payment_status_banner.dart';
import 'widgets/loan_quick_actions.dart';
import 'widgets/loan_skeleton_loader.dart';
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
              tooltip: 'Share schedule',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _shareSchedule(context, ref),
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
                  onShareSchedule: () => _shareSchedule(context, ref),
                ),
          error: (Object error, StackTrace stackTrace) => initialLoan == null
              ? Center(child: Text('Could not load loan: $error'))
              : _LoanDetailContent(
                  loan: initialLoan!,
                  onRecordPayment: () =>
                      context.push('/loans/$loanId/payments'),
                  onShareSchedule: () => _shareSchedule(context, ref),
                ),
          data: (Loan loan) => _LoanDetailContent(
            loan: loan,
            onRecordPayment: () => context.push('/loans/$loanId/payments'),
            onShareSchedule: () => _shareSchedule(context, ref),
          ),
        ),
      ),
    );
  }

  Future<void> _shareSchedule(BuildContext context, WidgetRef ref) async {
    final loan = ref.read(loanDetailProvider(loanId)).valueOrNull;
    if (loan == null) return;

    final buf = StringBuffer()
      ..writeln('📋 Repayment Schedule — ${loan.status}')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('Principal: ${formatCurrency(loan.originalPrincipal)}')
      ..writeln('Outstanding: ${formatCurrency(loan.outstandingPrincipal)}')
      ..writeln('Rate: ${formatInterestRate(loan.monthlyRate)} / mo')
      ..writeln('First due: ${formatDateShort(loan.firstDueDate)}')
      ..writeln('Final due: ${formatDateShort(loan.finalDueDate)}')
      ..writeln('');

    if (loan.installments.isNotEmpty) {
      buf.writeln('Installments:');
      for (final inst in loan.installments) {
        buf.writeln(
          '  #${inst.installmentNumber} — ${formatDateShort(inst.dueDate)} — '
          '${formatCurrency(inst.expectedPayment)} — ${inst.status}',
        );
      }
    }

    final text = buf.toString();

    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ShareSheet(loan: loan, text: text),
    );
  }
}

class _LoanDetailContent extends StatelessWidget {
  final Loan loan;
  final VoidCallback onRecordPayment;
  final VoidCallback onShareSchedule;

  const _LoanDetailContent({
    required this.loan,
    required this.onRecordPayment,
    required this.onShareSchedule,
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
                  const SizedBox(height: 12),
                  // Payment Status Banner (Overdue Alert / Healthy Status)
                  LoanPaymentStatusBanner(
                    loan: loan,
                    onPayNow: onRecordPayment,
                  ),
                  const SizedBox(height: 14),
                  // Quick Actions Bar
                  LoanQuickActions(loan: loan, onShare: onShareSchedule),
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
                  Tab(
                    text: 'Schedule',
                    icon: Icon(Icons.calendar_month_outlined, size: 20),
                  ),
                  Tab(
                    text: 'Overview',
                    icon: Icon(Icons.summarize_outlined, size: 20),
                  ),
                  Tab(
                    text: 'Payments',
                    icon: Icon(Icons.history_outlined, size: 20),
                  ),
                  Tab(
                    text: 'Documents',
                    icon: Icon(Icons.folder_open_outlined, size: 20),
                  ),
                  Tab(
                    text: 'Notes',
                    icon: Icon(Icons.note_alt_outlined, size: 20),
                  ),
                  Tab(
                    text: 'Activity',
                    icon: Icon(Icons.timeline_outlined, size: 20),
                  ),
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

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.loan, required this.text});

  final Loan loan;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final encoded = Uri.encodeComponent(text);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Share Schedule',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ShareOption(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () {
                    Navigator.of(context).pop();
                    _launch('https://wa.me/?text=$encoded');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShareOption(
                  icon: Icons.sms_outlined,
                  label: 'SMS',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.of(context).pop();
                    _launch('sms:?body=$encoded');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
