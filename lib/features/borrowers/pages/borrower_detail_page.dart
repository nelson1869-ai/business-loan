import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../loans/domain/models/loan.dart';
import '../../loans/presentation/providers/loans_provider.dart';
import '../domain/borrower_model.dart';
import '../providers/borrowers_state.dart';
import '../widgets/borrower_active_loan_card.dart';
import '../widgets/borrower_alert_banner.dart';
import '../widgets/borrower_emergency_guarantor_card.dart';
import '../widgets/borrower_financial_snapshot.dart';
import '../widgets/borrower_header_card.dart';
import '../widgets/borrower_payment_behavior_card.dart';
import '../widgets/borrower_quick_actions.dart';
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
          toolbarHeight: 52,
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
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: EdgeInsets.symmetric(horizontal: 16),
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Loans'),
              Tab(text: 'Payments'),
              Tab(text: 'Documents'),
              Tab(text: 'Notes'),
              Tab(text: 'Activity'),
            ],
          ),
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
    final borrowers = borrowersAsync.valueOrNull ?? const <Borrower>[];
    final borrower =
        borrowers.where((b) => b.id == borrowerId).firstOrNull ??
        (initialBorrower == null
            ? null
            : borrowers
                  .where(
                    (b) =>
                        b.phone == initialBorrower!.phone &&
                        b.nationalId == initialBorrower!.nationalId,
                  )
                  .firstOrNull) ??
        initialBorrower;

    if (borrower == null) {
      return const BorrowerSkeletonLoader();
    }

    final effectiveBorrowerId = borrower.id;
    final loansAsync = ref.watch(borrowerLoansProvider(effectiveBorrowerId));
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

    final overviewSections = <Widget>[
      BorrowerHeaderCard(borrower: borrower),
      if (overdueAmount > 0) ...[
        const SizedBox(height: 12),
        BorrowerAlertBanner(
          daysOverdue: daysOverdue > 0 ? daysOverdue : 1,
          overdueAmount: overdueAmount.toStringAsFixed(2),
          recommendedNextAction:
              'Contact borrower for immediate payment agreement',
          onTakeAction: () {
            if (activeLoan != null) {
              context.push('/loans/${activeLoan.id}/payments');
            }
          },
        ),
      ],
      const SizedBox(height: 14),
      BorrowerRecommendedActions(
        borrower: borrower,
        activeLoanId: activeLoan?.id,
      ),
      const SizedBox(height: 14),
      BorrowerQuickActions(
        borrower: borrower,
        activeLoanId: activeLoan?.id,
        activeLoan: activeLoan,
      ),
      const SizedBox(height: 16),
      BorrowerFinancialSnapshot(loans: loans),
      const SizedBox(height: 16),
      BorrowerPaymentBehaviorCard(loans: loans),
      if (activeLoan != null) ...[
        const SizedBox(height: 16),
        BorrowerActiveLoanCard(loan: activeLoan),
      ],
      const SizedBox(height: 16),
      BorrowerEmergencyGuarantorCard(borrower: borrower),
    ];

    return TabBarView(
      children: [
        OverviewTabView(borrower: borrower, leading: overviewSections),
        LoansTabView(borrower: borrower, loans: loans),
        PaymentsTabView(loans: loans),
        DocumentsTabView(borrowerId: effectiveBorrowerId),
        NotesTabView(borrowerId: effectiveBorrowerId),
        ActivityTabView(borrower: borrower),
      ],
    );
  }
}
