// Flutter Packages
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Core Network Services
import 'package:lending_nelson/core/network/offline_sync_service.dart';

// Presentation Layer Screens
import 'package:lending_nelson/features/auth/presentation/login_screen.dart';
import 'package:lending_nelson/features/dashboard/pages/dashboard_page.dart';
import 'package:lending_nelson/features/dashboard/pages/settings_page.dart';
import 'package:lending_nelson/features/dev_tools/pages/dev_tools_page.dart';
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
    GoRoute(
      path: '/dev-tools',
      builder: (context, state) => const DevToolsPage(),
    ),
  ],
);

/// Displays routed dashboard content above the shared bottom navigation bar.
class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    int selectedIndex = 0;
    if (location.startsWith('/borrowers')) {
      selectedIndex = 1;
    } else if (location.startsWith('/settings')) {
      selectedIndex = 2;
    }

    final isOnlineAsync = ref.watch(isOnlineProvider);
    final isOnline = isOnlineAsync.asData?.value ?? true;
    final pendingCountAsync = ref.watch(offlineSyncPendingCountProvider);
    final pendingCount = pendingCountAsync.asData?.value ?? 0;

    return Scaffold(
      body: Column(
        children: [
          if (!isOnline)
            Container(
              width: double.infinity,
              color: Colors.amber.shade800,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      pendingCount > 0
                          ? 'Working Offline — $pendingCount items queued'
                          : 'Working Offline',
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
          Expanded(child: child),
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
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Borrowers'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
