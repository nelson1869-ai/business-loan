import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        context.go('/login');
      }
    });
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
