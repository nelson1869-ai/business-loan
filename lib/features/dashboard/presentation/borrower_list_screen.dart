// Flutter and GoRouter packages
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// State Layer Providers
import 'providers/borrowers_provider.dart';

/// Displays the list of registered borrowers with PII-masked identifiers.
///
/// File: `lib/features/dashboard/presentation/borrower_list_screen.dart`
///
/// Data Flow Diagram:
/// ```text
///  +-----------------------------------+
///  |      borrowers_provider.dart      |
///  |     (borrowersNotifierProvider)   |
///  +-----------------+-----------------+
///                    |
///                    | ref.watch (Listens to state changes)
///                    v
///  +-----------------------------------+
///  |     borrower_list_screen.dart     |
///  |        (BorrowerListScreen)       |
///  +-----------------+-----------------+
///                    |
///                    | Tap Card -> Navigate (Placeholder)
///                    v
///  +-----------------------------------+
///  |      (Borrower Details Screen)    |
///  +-----------------------------------+
/// ```
class BorrowerListScreen extends ConsumerWidget {
  const BorrowerListScreen({super.key});

  /// Masks the national ID for PII (Personally Identifiable Information) protection.
  ///
  /// Displays only the last 4 characters, padding the rest with asterisks.
  String _maskNationalId(String value) {
    if (value.length <= 4) return '****';
    return '${'*' * (value.length - 4)}${value.substring(value.length - 4)}';
  }

  /// Masks the phone number for PII protection.
  ///
  /// Shows the first 4 and last 3 digits, masking the middle.
  String _maskPhone(String value) {
    if (value.length <= 4) return '****';
    return '${value.substring(0, 4)}****${value.substring(value.length - 3)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the AsyncNotifier to dynamically listen to state changes (loading/error/data).
    final borrowersAsync = ref.watch(borrowersNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrowers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () {
              context.go('/borrowers/register');
            },
            tooltip: 'Register Borrower',
          ),
        ],
      ),
      // Handle loading, error, and data states elegantly using Riverpod's AsyncValue.when.
      body: borrowersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (borrowers) {
          if (borrowers.isEmpty) {
            return const Center(child: Text('No borrowers found'));
          }
          return ListView.builder(
            itemCount: borrowers.length,
            itemBuilder: (context, index) {
              final borrower = borrowers[index];
              final fullName = borrower.fullName;
              final nationalId = borrower.nationalId;
              final phone = borrower.phone;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(fullName),
                  subtitle: Text(
                    'National ID: ${_maskNationalId(nationalId)} | '
                    'Phone: ${_maskPhone(phone)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // We'll hook up the borrower details route later
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the registration form subroute
          context.go('/borrowers/register');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
