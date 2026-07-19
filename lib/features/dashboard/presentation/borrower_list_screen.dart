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
///  +---------+-----------+------------+
///            |           |
///  Tap Edit  |           | Tap Delete
///            v           v
///  navigate to      confirm dialog ->
///  /borrowers/      deleteBorrower(id)
///  register         (notifier)
///  (with extra:
///   borrower)
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
                  // Popup menu with Edit and Delete actions
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Actions',
                    onSelected: (value) async {
                      if (value == 'edit') {
                        // Navigate to edit mode — pass the full Borrower via state.extra
                        context.go('/borrowers/register', extra: borrower);
                      } else if (value == 'delete') {
                        // Show confirmation dialog before irreversible deletion
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Borrower'),
                            content: Text(
                              'Are you sure you want to delete $fullName? '
                              'This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          await ref
                              .read(borrowersNotifierProvider.notifier)
                              .deleteBorrower(borrower.id);
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
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
