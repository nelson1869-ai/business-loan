import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:borrower_mobile/core/auth/auth_state.dart';
import 'package:borrower_mobile/features/authentication/login_screen.dart';
import 'package:borrower_mobile/features/authentication/otp_screen.dart';
import 'package:borrower_mobile/features/dashboard/dashboard_screen.dart';
import 'package:borrower_mobile/features/loans/loans_screen.dart';
import 'package:borrower_mobile/features/notifications/notifications_screen.dart';
import 'package:borrower_mobile/features/payments/payments_screen.dart';
import 'package:borrower_mobile/features/profile/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider.notifier);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _ListenableAdapter(authNotifier),
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isAuth = authState.status == AuthStatus.authenticated;
      final loc = state.matchedLocation;

      final isUnauthRoute = loc == '/login' || loc == '/verify' || loc == '/';

      if (!isAuth && !isUnauthRoute) {
        return '/login';
      }
      if (isAuth && (loc == '/login' || loc == '/verify' || loc == '/')) {
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
        path: '/verify',
        builder: (context, state) {
          final invCode = state.extra as String?;
          return OtpScreen(invitationCode: invCode);
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/loans',
        builder: (context, state) => const LoansScreen(),
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
