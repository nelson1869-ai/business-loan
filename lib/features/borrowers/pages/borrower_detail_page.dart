import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../loans/domain/models/loan.dart';
import '../../loans/presentation/providers/loans_provider.dart';
import '../domain/borrower_model.dart';
import '../providers/borrower_recommendation_provider.dart';
import '../providers/borrowers_state.dart';
import '../widgets/borrower_active_loan_card.dart';
import '../widgets/borrower_alert_banner.dart';
import '../widgets/borrower_customer_score_card.dart';
import '../widgets/borrower_emergency_guarantor_card.dart';
import '../widgets/borrower_financial_snapshot.dart';
import '../widgets/borrower_header_card.dart';
import '../widgets/borrower_payment_behavior_card.dart';
import '../widgets/borrower_quick_actions.dart';
import '../widgets/borrower_recommendation_card.dart';
import '../widgets/borrower_recommended_actions.dart';
import '../widgets/borrower_skeleton_loader.dart';
import '../widgets/tabs/activity_tab_view.dart';
import '../widgets/tabs/documents_tab_view.dart';
import '../widgets/tabs/loans_tab_view.dart';
import '../widgets/tabs/notes_tab_view.dart';
import '../widgets/tabs/overview_tab_view.dart';
import '../widgets/tabs/payments_tab_view.dart';

/// Redesigned Material 3 Customer 360° Borrower Profile & Relationship Dashboard.
class BorrowerDetailPage extends ConsumerWidget {
  final String borrowerId;
  final Borrower? initialBorrower;

  const BorrowerDetailPage({
    super.key,
    required this.borrowerId,
    this.initialBorrower,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/borrowers');
              }
            },
          ),
          title: Text(initialBorrower?.fullName ?? 'Customer 360° Profile'),
        ),
        body: _BorrowerDetailContent(
          borrowerId: borrowerId,
          initialBorrower: initialBorrower,
        ),
      ),
    );
  }
}

class _BorrowerDetailContent extends ConsumerWidget {
  final String borrowerId;
  final Borrower? initialBorrower;

  const _BorrowerDetailContent({
    required this.borrowerId,
    this.initialBorrower,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borrowersAsync = ref.watch(borrowersNotifierProvider);
    final borrower =
        borrowersAsync.valueOrNull
            ?.where((b) => b.id == borrowerId)
            .firstOrNull ??
        initialBorrower;

    if (borrower == null) {
      return const BorrowerSkeletonLoader();
    }

    final loansAsync = ref.watch(borrowerLoansProvider(borrowerId));
    final recommendationAsync = ref.watch(
      borrowerRecommendationProvider(borrowerId),
    );
    final theme = Theme.of(context);

    final loans = loansAsync.valueOrNull ?? const <Loan>[];
    final activeLoan = loans
        .where((l) => l.status == 'Active' || l.status == 'Overdue')
        .firstOrNull;

    int daysOverdue = 0;
    double overdueAmount = 0;
    for (final loan in loans) {
      if (loan.status == 'Overdue') {
        final outstanding = double.tryParse(loan.outstandingPrincipal) ?? 0;
        overdueAmount += outstanding;
        for (final inst in loan.installments) {
          if (inst.status == 'Overdue') {
            final due = DateTime.tryParse(inst.dueDate);
            if (due != null) {
              final diff = DateTime.now().difference(due).inDays;
              if (diff > daysOverdue) daysOverdue = diff;
            }
          }
        }
      }
    }

    final recommendation = recommendationAsync.valueOrNull;

    return Column(
      children: [
        Expanded(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Material 3 Customer 360 Header Card
                        BorrowerHeaderCard(
                          borrower: borrower,
                          recommendation: recommendation,
                        ),
                        const SizedBox(height: 12),
                        // 2. Customer Score Card
                        BorrowerCustomerScoreCard(
                          borrower: borrower,
                          recommendation: recommendation,
                        ),
                        if (overdueAmount > 0) ...[
                          const SizedBox(height: 12),
                          BorrowerAlertBanner(
                            daysOverdue: daysOverdue > 0 ? daysOverdue : 1,
                            overdueAmount: overdueAmount.toStringAsFixed(2),
                            recommendedNextAction:
                                'Contact borrower for immediate payment agreement',
                            onTakeAction: () {
                              if (activeLoan != null) {
                                context.push(
                                  '/loans/${activeLoan.id}/payments',
                                );
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 14),
                        // 3. Recommended Officer Next Actions
                        BorrowerRecommendedActions(
                          borrower: borrower,
                          activeLoanId: activeLoan?.id,
                        ),
                        const SizedBox(height: 14),
                        // 4. Quick Action Buttons Bar
                        BorrowerQuickActions(
                          borrower: borrower,
                          activeLoanId: activeLoan?.id,
                        ),
                        const SizedBox(height: 16),
                        // 5. Financial Snapshot Grid
                        BorrowerFinancialSnapshot(loans: loans),
                        const SizedBox(height: 16),
                        // 6. Payment Behavior Analytics
                        BorrowerPaymentBehaviorCard(loans: loans),
                        const SizedBox(height: 16),
                        // 7. Active Loan Card
                        if (activeLoan != null) ...[
                          BorrowerActiveLoanCard(loan: activeLoan),
                          const SizedBox(height: 16),
                        ],
                        // 8. Emergency Contact & Guarantor Card
                        BorrowerEmergencyGuarantorCard(borrower: borrower),
                        const SizedBox(height: 16),
                        // 9. AI Credit Recommendation Widget
                        if (recommendation != null)
                          BorrowerRecommendationCard(
                            recommendation: recommendation,
                            onApplyRecommended: () {
                              context.push(
                                '/borrowers/$borrowerId/loans/new',
                                extra: borrower,
                              );
                            },
                          ),
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
                          text: 'Overview',
                          icon: Icon(Icons.person_outline, size: 20),
                        ),
                        Tab(
                          text: 'Loans',
                          icon: Icon(Icons.credit_card_outlined, size: 20),
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
                OverviewTabView(borrower: borrower),
                LoansTabView(borrower: borrower, loans: loans),
                PaymentsTabView(loans: loans),
                DocumentsTabView(borrowerId: borrowerId),
                NotesTabView(borrowerId: borrowerId),
                ActivityTabView(borrower: borrower),
              ],
            ),
          ),
        ),
      ],
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
