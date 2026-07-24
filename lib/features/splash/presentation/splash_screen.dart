import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../auth/data/auth_repository.dart';

/// Displays application branding while restoring any securely saved session.
///
/// File: `lib/features/splash/presentation/splash_screen.dart`
///
/// Data Flow Diagram:
/// ```text
///  +-----------+     +--------------------+     +-------------------+
///  | main.dart | --> | splash_screen.dart | --> | dashboard / login |
///  +-----------+     +--------------------+     +-------------------+
/// ```
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    final sessionCheck = ref.read(authRepositoryProvider).hasStoredSession();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final hasStoredSession = await sessionCheck;
    if (!mounted) return;

    context.go(hasStoredSession ? '/dashboard' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance,
              size: 80,
              color: AppTheme.accentColor, // Teal Accent
            ),
            SizedBox(height: 24),
            Text(
              'Lending Nelson',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Secure Mobile Lending',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(color: AppTheme.accentColor),
          ],
        ),
      ),
    );
  }
}
