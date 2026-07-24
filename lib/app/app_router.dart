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

/// Defines the application's routes and the shared navigation shell.
///
/// File: `lib/app/app_router.dart`
///
/// Data Flow Diagram:
/// ```text
///  +------------+     +-----------------+     +-----------------------+
///  |  app.dart  | --> | app_router.dart | --> | splash_screen.dart    |
///  +------------+     +--------+--------+     | login_screen.dart     |
///                              |              | dashboard_screen.dart |
///                              +------------> | borrower_*.dart       |
///                                             | settings_screen.dart  |
///                                             +-----------------------+
/// ```
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
    final pendingCount = ref.watch(offlineSyncPendingCountProvider);

    final showBanner =
        serverStatus != ServerStatus.serverReady || pendingCount > 0;
    final bannerConfig = _bannerConfig(serverStatus, pendingCount);

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleSystemBack(location);
      },
      child: Scaffold(
        body: Column(
          children: [
            if (showBanner)
              Container(
                width: double.infinity,
                color: bannerConfig.backgroundColor,
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 16,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(bannerConfig.icon, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        bannerConfig.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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

  _BannerData _bannerConfig(ServerStatus status, int pendingCount) {
    switch (status) {
      case ServerStatus.offline:
        return _BannerData(
          backgroundColor: Colors.amber.shade900,
          icon: Icons.wifi_off,
          message: pendingCount > 0
              ? 'Working Offline ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â $pendingCount items queued'
              : 'Working Offline',
        );
      case ServerStatus.networkAvailable:
        return _BannerData(
          backgroundColor: Colors.blue.shade800,
          icon: Icons.sync,
          message: 'Server ConnectingÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦',
        );
      case ServerStatus.serverUnavailable:
        return _BannerData(
          backgroundColor: Colors.deepOrange.shade800,
          icon: Icons.cloud_off,
          message: 'Network Available ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Server Unreachable',
        );
      case ServerStatus.serverReady:
        return _BannerData(
          backgroundColor: Colors.teal.shade800,
          icon: Icons.cloud_done,
          message: 'Online ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Syncing $pendingCount items',
        );
    }
  }
}

class _BannerData {
  const _BannerData({
    required this.backgroundColor,
    required this.icon,
    required this.message,
  });

  final Color backgroundColor;
  final IconData icon;
  final String message;
}
