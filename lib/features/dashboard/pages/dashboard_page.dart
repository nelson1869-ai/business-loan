import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/offline_sync_service.dart';
import '../domain/dashboard_data.dart';
import '../providers/dashboard_state.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/portfolio_summary_cards.dart';
import '../widgets/quick_actions_section.dart';
import '../widgets/todays_collections_section.dart';
import '../widgets/recent_activity_section.dart';

import '../widgets/owner_financial_summary_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final theme = Theme.of(context);

    ref.listen(dashboardProvider, (prev, next) {
      if (!next.isLoading && next.error != null && prev?.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        toolbarHeight: 48,
        titleSpacing: 16,
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        elevation: 0,
        scrolledUnderElevation: 3.0,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        surfaceTintColor: theme.colorScheme.surface,
        backgroundColor: theme.colorScheme.surface,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
            height: 1.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
          ),
          Consumer(
            builder: (context, ref, child) {
              final pendingCount = ref.watch(offlineSyncPendingCountProvider);
              if (pendingCount <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Badge(
                  label: Text('$pendingCount'),
                  child: IconButton(
                    icon: const Icon(Icons.cloud_upload_outlined),
                    tooltip: '$pendingCount offline items pending sync',
                    onPressed: () => context.go('/settings'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardProvider.notifier).loadDashboard(),
        child: _buildBody(context, theme, state),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin-assistant'),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Ask Admin AI'),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    DashboardState state,
  ) {
    if (state.metrics == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(state.error ?? 'Loading dashboard...'),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(dashboardProvider.notifier).loadDashboard(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      );
    }

    final metrics = state.metrics!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const DashboardHeader(),
        const SizedBox(height: 16),
        OwnerFinancialSummaryCard(
          totalPrincipalDisbursed: metrics.totalPrincipalDisbursed,
          monthlyInterestIncome: metrics.monthlyInterestIncome,
          outstandingBalance: metrics.outstandingBalance,
          averageInterestRate: metrics.weightedAverageRate,
        ),
        const SizedBox(height: 20),
        PortfolioSummaryCards(
          activeBorrowers: metrics.activeBorrowers,
          outstandingBalance: metrics.outstandingBalance,
          overdueCount: metrics.overdueLoanCount,
          overdueAmount: metrics.overdueAmount,
          collectionDueToday: metrics.collectionDueToday,
          collectionCountToday: metrics.collectionCountToday,
          totalActiveLoanCount: metrics.totalActiveLoanCount,
        ),
        const SizedBox(height: 24),
        QuickActionsSection(),
        if (state.dueItems.isNotEmpty) ...[
          const SizedBox(height: 24),
          TodaysCollectionsSection(items: state.dueItems),
        ],
        if (state.recentActivities.isNotEmpty) ...[
          const SizedBox(height: 24),
          RecentActivitySection(activities: state.recentActivities),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}
