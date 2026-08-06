import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:borrower_mobile/core/auth/auth_state.dart';
import 'package:borrower_mobile/features/authentication/activation_screen.dart';
import 'package:borrower_mobile/features/authentication/login_screen.dart';
import 'package:borrower_mobile/features/dashboard/dashboard_screen.dart';
import 'package:borrower_mobile/features/loans/loan_detail_screen.dart';
import 'package:borrower_mobile/features/loans/loans_screen.dart';
import 'package:borrower_mobile/features/notifications/notifications_screen.dart';
import 'package:borrower_mobile/features/payments/payments_screen.dart';
import 'package:borrower_mobile/features/profile/profile_screen.dart';
import 'package:borrower_mobile/features/registration/registration_screen.dart';
import 'package:borrower_mobile/features/registration/registration_status_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider.notifier);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _ListenableAdapter(authNotifier),
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isAuth = authState.status == AuthStatus.authenticated;
      final isInitializing = authState.status == AuthStatus.unknown;
      final loc = state.matchedLocation;

      if (isInitializing) {
        return loc == '/' ? null : '/';
      }

      final isLoggingInOrVerifying = loc == '/login' ||
          loc == '/verify' ||
          loc == '/activate' ||
          loc == '/register' ||
          loc == '/registration-status';

      if (!isAuth) {
        return isLoggingInOrVerifying ? null : '/login';
      }

      if (isAuth && (isLoggingInOrVerifying || loc == '/')) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/activate',
        builder: (context, state) => const ActivationScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (context, state) => const ActivationScreen(),
      ),
      GoRoute(
          path: '/register',
          builder: (context, state) => const RegistrationScreen()),
      GoRoute(
          path: '/registration-status',
          builder: (context, state) => const RegistrationStatusScreen()),
      GoRoute(
        path: '/home',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/loans',
        builder: (context, state) => const LoansScreen(),
        routes: [
          GoRoute(
            path: ':loanId',
            builder: (context, state) {
              final loanId = state.pathParameters['loanId'] ?? '';
              return LoanDetailScreen(loanId: loanId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/payments',
        builder: (context, state) => const PaymentsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});

class _ListenableAdapter extends ChangeNotifier {
  _ListenableAdapter(StateNotifier notifier) {
    notifier.addListener((_) => notifyListeners());
  }
}
