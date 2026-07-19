// Flutter Packages
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Presentation Layer Screens
import 'package:lending_nelson/features/auth/presentation/login_screen.dart';
import 'package:lending_nelson/features/dashboard/presentation/borrower_list_screen.dart';
import 'package:lending_nelson/features/dashboard/presentation/borrower_registration_screen.dart';
import 'package:lending_nelson/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lending_nelson/features/dashboard/presentation/settings_screen.dart';
import 'package:lending_nelson/features/splash/presentation/splash_screen.dart';

// Feature Domain Layer (carries Borrower payload between routes via state.extra)
import 'package:lending_nelson/features/dashboard/domain/models/borrower.dart';

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
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/borrowers',
          builder: (context, state) => const BorrowerListScreen(),
          routes: [
            GoRoute(
              path: 'register',
              builder: (context, state) {
                // Extract optional Borrower from GoRouter state.extra.
                // null  → Add Mode (blank registration form)
                // non-null → Edit Mode (prefilled form with existing borrower data)
                final borrower = state.extra as Borrower?;

                return BorrowerRegistrationScreen(borrower: borrower);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);

/// Displays routed dashboard content above the shared bottom navigation bar.
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    int selectedIndex = 0;
    if (location.startsWith('/borrowers')) {
      selectedIndex = 1;
    } else if (location.startsWith('/settings')) {
      selectedIndex = 2;
    }

    return Scaffold(
      body: child,
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
