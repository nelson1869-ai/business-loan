import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lending_nelson/core/presentation/design_system/design_system.dart';
import '../providers/dashboard_state.dart';
import '../providers/financial_report_provider.dart';
import '../widgets/reports/reports_header_card.dart';
import '../widgets/reports/reports_kpi_cards.dart';
import '../widgets/reports/reports_officer_leaderboard.dart';
import '../widgets/reports/reports_risk_analysis_card.dart';
import '../widgets/reports/reports_trend_charts.dart';

/// Executive Reports & Analytics Dashboard.
class ReportsAnalyticsPage extends ConsumerStatefulWidget {
  const ReportsAnalyticsPage({super.key});

  @override
  ConsumerState<ReportsAnalyticsPage> createState() =>
      _ReportsAnalyticsPageState();
}

class _ReportsAnalyticsPageState extends ConsumerState<ReportsAnalyticsPage> {
  String _selectedPeriod = 'This Month';

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);
    final reportAsync = ref.watch(financialReportProvider(_selectedPeriod));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Executive Reports & Analytics'),
      ),
      body: dashboardState.isLoading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                AppCardSkeleton(),
                SizedBox(height: 12),
                AppCardSkeleton(),
                SizedBox(height: 12),
                AppCardSkeleton(),
              ],
            )
          : dashboardState.error != null
          ? Center(
              child: AppErrorState(
                error: dashboardState.error!,
                onRetry: () =>
                    ref.read(dashboardProvider.notifier).loadDashboard(),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.read(dashboardProvider.notifier).loadDashboard(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Executive Header Card
                  ReportsHeaderCard(
                    selectedPeriod: _selectedPeriod,
                    isOnline: dashboardState.isOnline,
                    report: reportAsync.valueOrNull,
                    onPeriodChanged: (val) {
                      setState(() => _selectedPeriod = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  // 2. Key Performance Indicators Grid
                  if (dashboardState.metrics != null)
                    reportAsync.when(
                      loading: () => const AppCardSkeleton(),
                      error: (error, _) => AppErrorState(
                        error: error.toString(),
                        onRetry: () => ref.invalidate(
                          financialReportProvider(_selectedPeriod),
                        ),
                      ),
                      data: (report) => ReportsKpiCards(
                        metrics: dashboardState.metrics!,
                        report: report,
                      ),
                    ),
                  const SizedBox(height: 16),
                  // 3. Visual Trend Charts
                  const ReportsTrendCharts(),
                  const SizedBox(height: 16),
                  // 4. Officer Leaderboard Table
                  reportAsync.valueOrNull == null
                      ? const SizedBox.shrink()
                      : ReportsOfficerLeaderboard(
                          report: reportAsync.requireValue,
                        ),
                  const SizedBox(height: 16),
                  // 5. Risk & PAR Aging Analysis Card
                  reportAsync.valueOrNull == null
                      ? const SizedBox.shrink()
                      : ReportsRiskAnalysisCard(
                          report: reportAsync.requireValue,
                        ),
                ],
              ),
            ),
    );
  }
}
