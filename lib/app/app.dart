import 'package:flutter/material.dart';
import 'app_router.dart';
import 'app_theme.dart';
import '../core/security/session_guard.dart';

/// Configures the root Material application, router, and visual themes.
///
/// File: `lib/app/app.dart`
///
/// Data Flow Diagram:
/// ```text
///  +------------------+     +------------------+     +-------------------+
///  |    main.dart     | --> |     app.dart     | --> | app_router.dart   |
///  +------------------+     +--------+---------+     +-------------------+
///                                    |
///                                    +-----------> app_theme.dart
/// ```
class LendingNelsonApp extends StatelessWidget {
  const LendingNelsonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Lending Nelson',
      routerConfig: appRouter,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode:
          ThemeMode.system, // Automatically matches system dark/light mode
      debugShowCheckedModeBanner: false,
      builder: (context, child) => SessionGuard(child: child!),
    );
  }
}
