import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/mocks/mock_data_service.dart';

/// Provider to load borrowers asynchronously from the mock data service.
///
/// It watches [mockDataServiceProvider] and automatically rebuilds when it changes.
final borrowersProvider = FutureProvider<List<dynamic>>((ref) async {
  final mockService = ref.watch(mockDataServiceProvider);
  return mockService.loadBorrowers();
});

/// Displays the list of registered borrowers with PII-masked identifiers.
///
/// Uses [borrowersProvider] to handle asynchronous data retrieval.
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
    // Watch the future provider to dynamically listen to changes and async states.
    final borrowersAsync = ref.watch(borrowersProvider);

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
              // Combine firstName and lastName from the JSON file
              final fullName =
                  '${borrower['firstName']} ${borrower['lastName']}';
              // Explicitly cast fields from dynamic JSON lookups to String? to prevent
              // Dart static analysis errors: 'dynamic' can't be assigned to 'String'.
              final nationalId = borrower['nationalId'] as String? ?? '';
              final phone = borrower['phone'] as String? ?? '';

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
