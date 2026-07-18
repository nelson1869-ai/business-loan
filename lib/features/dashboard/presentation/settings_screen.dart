import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        children: [
          // Settings Group in a unified Card container
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.badge_outlined),
                  title: Text('Officer Profile'),
                  subtitle: Text('ID: officer-999 | Role: Loan Officer'),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Theme.of(context).dividerTheme.color,
                ),
                const ListTile(
                  leading: Icon(Icons.apartment_outlined),
                  title: Text('Assigned Branch'),
                  subtitle: Text('Nairobi Central (ID: branch-001)'),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Theme.of(context).dividerTheme.color,
                ),
                const ListTile(
                  leading: Icon(Icons.phone_android_outlined),
                  title: Text('App Version'),
                  subtitle: Text('1.0.0 (Build 1)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Logout Action styled with the theme's error color
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // Log the user out and redirect to the login screen
              context.go('/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
