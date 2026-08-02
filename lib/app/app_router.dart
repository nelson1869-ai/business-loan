// Flutter Packages
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Core Network Services
import 'package:lending_nelson/core/network/offline_sync_service.dart';
import 'package:lending_nelson/core/network/server_health_service.dart';

// Presentation Layer Screens
import 'package:lending_nelson/features/auth/presentation/login_screen.dart';
import 'package:lending_nelson/features/dashboard/pages/dashboard_page.dart';
import 'package:lending_nelson/features/dashboard/pages/settings_page.dart';
import 'package:lending_nelson/features/dashboard/pages/sync_management_screen.dart';
import 'package:lending_nelson/features/borrowers/pages/borrower_list_page.dart';
import 'package:lending_nelson/features/borrowers/pages/borrower_detail_page.dart';
import 'package:lending_nelson/features/borrowers/pages/borrower_registration_page.dart';
import 'package:lending_nelson/features/borrowers/domain/borrower_model.dart';
import 'package:lending_nelson/features/splash/presentation/splash_screen.dart';
import 'package:lending_nelson/features/loans/domain/models/loan.dart';
import 'package:lending_nelson/features/loans/presentation/loan_create_screen.dart';
import 'package:lending_nelson/features/loans/presentation/loan_detail_screen.dart';
import 'package:lending_nelson/features/loans/presentation/loans_list_page.dart';
import 'package:lending_nelson/features/loans/presentation/payment_screen.dart';
import 'package:lending_nelson/features/loans/presentation/todays_collections_page.dart';
import 'package:lending_nelson/features/borrower_communication/presentation/send_to_borrower_notification_page.dart';

import 'package:lending_nelson/features/dashboard/pages/notifications_center_page.dart';
import 'package:lending_nelson/features/dashboard/pages/reports_analytics_page.dart';
import 'package:lending_nelson/features/dashboard/pages/admin_assistant_page.dart';
import 'package:lending_nelson/features/accounting/presentation/journal_list_page.dart';
import 'package:lending_nelson/features/approvals/presentation/approval_inbox_page.dart';
import 'package:lending_nelson/features/collection_sessions/presentation/collection_sessions_page.dart';
import 'package:lending_nelson/features/loan_policies/presentation/loan_policy_page.dart';
import 'package:lending_nelson/features/operational_reports/presentation/operational_reports_page.dart';
import 'package:lending_nelson/features/operations/presentation/operations_hub_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/borrowers',
          builder: (context, state) => const BorrowerListPage(),
        ),
        GoRoute(
          path: '/loans',
          builder: (context, state) => const LoansListPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/sync-management',
      builder: (context, state) => const SyncManagementScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsCenterPage(),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportsAnalyticsPage(),
    ),
    GoRoute(
      path: '/admin-assistant',
      builder: (context, state) => const AdminAssistantPage(),
    ),
    GoRoute(
      path: '/operations',
      builder: (context, state) => const OperationsHubPage(),
      routes: [
        GoRoute(
          path: 'policies',
          builder: (context, state) => const LoanPolicyPage(),
        ),
        GoRoute(
          path: 'approvals',
          builder: (context, state) => const ApprovalInboxPage(),
        ),
        GoRoute(
          path: 'collections',
          builder: (context, state) => const CollectionSessionsPage(),
        ),
        GoRoute(
          path: 'accounting',
          builder: (context, state) => const JournalListPage(),
        ),
        GoRoute(
          path: 'reports',
          builder: (context, state) => const OperationalReportsPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/borrowers/register',
      builder: (context, state) {
        final borrower = state.extra as Borrower?;
        return BorrowerRegistrationPage(borrower: borrower);
      },
    ),
    GoRoute(
      path: '/borrowers/:borrowerId',
      builder: (context, state) => BorrowerDetailPage(
        borrowerId: state.pathParameters['borrowerId']!,
        initialBorrower: state.extra as Borrower?,
      ),
    ),
    GoRoute(
      path: '/borrowers/:borrowerId/loans/new',
      builder: (context, state) => LoanCreateScreen(
        borrowerId: state.pathParameters['borrowerId']!,
        borrower: state.extra as Borrower?,
      ),
    ),
    GoRoute(
      path: '/loans/:loanId',
      builder: (context, state) => LoanDetailScreen(
        loanId: state.pathParameters['loanId']!,
        initialLoan: state.extra as Loan?,
      ),
      routes: [
        GoRoute(
          path: 'payments',
          builder: (context, state) =>
              PaymentScreen(loanId: state.pathParameters['loanId']!),
        ),
      ],
    ),
    GoRoute(
      path: '/loans/:loanId/send',
      builder: (context, state) => SendToBorrowerNotificationPage(
        loanId: state.pathParameters['loanId']!,
      ),
    ),
    GoRoute(
      path: '/collections/today',
      builder: (context, state) => const TodaysCollectionsPage(),
    ),
  ],
);

/// Shared shell layout wrapping tabs with an accurate, multi-state status banner.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  DateTime? _lastBackPressTime;

  void _handleSystemBack(String location) {
    if (location == '/dashboard') {
      final now = DateTime.now();
      if (_lastBackPressTime == null ||
          now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
        _lastBackPressTime = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit application'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        SystemNavigator.pop();
      }
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    int selectedIndex = 0;
    if (location.startsWith('/borrowers')) {
      selectedIndex = 1;
    } else if (location.startsWith('/settings')) {
      selectedIndex = 2;
    }

    final serverStatus = ref.watch(serverStatusNotifierProvider);
    final queueState = ref.watch(offlineSyncQueueNotifierProvider);
    final bannerConfig = _bannerConfig(serverStatus, queueState);

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleSystemBack(location);
      },
      child: Scaffold(
        body: Column(
          children: [
            Semantics(
              liveRegion: true,
              label: bannerConfig.message,
              button: true,
              child: InkWell(
                onTap: () => context.push('/sync-management'),
                child: Container(
                  width: double.infinity,
                  color: bannerConfig.backgroundColor,
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 16,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        Icon(bannerConfig.icon, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bannerConfig.message,
                            maxLines: 2,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (bannerConfig.canRetry)
                          IconButton(
                            tooltip: 'Retry synchronization',
                            visualDensity: VisualDensity.compact,
                            color: Colors.white,
                            onPressed: () => ref
                                .read(offlineSyncServiceProvider)
                                .drainQueue(force: true),
                            icon: const Icon(Icons.refresh, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: widget.child),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) {
            switch (index) {
              case 0:
                context.go('/dashboard');
                break;
              case 1:
                context.go('/borrowers');
                break;
              case 2:
                context.go('/settings');
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Borrowers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  _BannerData _bannerConfig(ServerStatus status, OfflineQueueState queueState) {
    final pendingCount = queueState.pendingCount;
    final failed =
        queueState.retryableFailedCount +
        queueState.permanentlyFailedCount +
        queueState.conflictCount;
    final lastSync = queueState.lastSyncedAt?.toUtc().add(
      const Duration(hours: 8),
    );
    final lastSyncLabel = lastSync == null
        ? 'No completed sync yet'
        : 'Last sync ${lastSync.hour.toString().padLeft(2, '0')}:'
              '${lastSync.minute.toString().padLeft(2, '0')}';
    if (failed > 0) {
      return _BannerData(
        backgroundColor: Colors.red.shade800,
        icon: Icons.sync_problem,
        message: 'Sync failed · $failed need attention · $lastSyncLabel',
        canRetry: true,
      );
    }
    if (queueState.isSyncing) {
      return _BannerData(
        backgroundColor: Colors.blue.shade800,
        icon: Icons.sync,
        message:
            'Syncing ${queueState.processedCount}/${queueState.processingTotal}'
            ' · $pendingCount queued',
      );
    }
    switch (status) {
      case ServerStatus.offline:
        return _BannerData(
          backgroundColor: Colors.amber.shade900,
          icon: Icons.wifi_off,
          message: pendingCount > 0
              ? 'Offline · $pendingCount queued · $lastSyncLabel'
              : 'Offline · $lastSyncLabel',
        );
      case ServerStatus.networkAvailable:
        return _BannerData(
          backgroundColor: Colors.blue.shade800,
          icon: Icons.sync,
          message: 'Waiting for server · $pendingCount queued · $lastSyncLabel',
        );
      case ServerStatus.serverUnavailable:
        return _BannerData(
          backgroundColor: Colors.deepOrange.shade800,
          icon: Icons.cloud_off,
          message: 'Waiting for server · $pendingCount queued · $lastSyncLabel',
        );
      case ServerStatus.serverReady:
        return _BannerData(
          backgroundColor: Colors.teal.shade800,
          icon: Icons.cloud_done,
          message: pendingCount > 0
              ? 'Online · $pendingCount waiting to sync · $lastSyncLabel'
              : 'Online · Queue clear · $lastSyncLabel',
        );
    }
  }
}

class _BannerData {
  const _BannerData({
    required this.backgroundColor,
    required this.icon,
    required this.message,
    this.canRetry = false,
  });

  final Color backgroundColor;
  final IconData icon;
  final String message;
  final bool canRetry;
}
