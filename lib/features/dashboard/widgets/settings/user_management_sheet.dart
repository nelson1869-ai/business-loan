import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

import '../../../users/data/user_repository.dart';
import '../../../users/providers/user_provider.dart';

class UserManagementSheet extends ConsumerStatefulWidget {
  const UserManagementSheet({super.key});

  @override
  ConsumerState<UserManagementSheet> createState() =>
      _UserManagementSheetState();
}

class _UserManagementSheetState extends ConsumerState<UserManagementSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final users = usersAsync.valueOrNull ?? const [];
    final filtered = users.where((user) {
      final query = _query.toLowerCase();
      return query.isEmpty ||
          user.username.toLowerCase().contains(query) ||
          user.role.toLowerCase().contains(query);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.people_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'User Management',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Create user',
                  onPressed: () => _createUser(context),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppSearchBar(
              controller: _searchController,
              hintText: 'Search username or role',
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: usersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => AppErrorState(
                  error:
                      'Administrator access is required. Check your connection or permissions.',
                  onRetry: () => ref.invalidate(usersProvider),
                ),
                data: (_) => filtered.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.person_off_outlined,
                        title: 'No Users Found',
                        description: 'No accounts match this search.',
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final user = filtered[index];
                          return AppCard(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                child: Text(user.username[0].toUpperCase()),
                              ),
                              title: Text(user.username),
                              subtitle: Text(
                                'Created ${user.createdAt.month}/${user.createdAt.day}/${user.createdAt.year}',
                              ),
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Change role',
                                onSelected: (role) =>
                                    _updateRole(user.id, role),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'officer',
                                    child: Text('Set as Officer'),
                                  ),
                                  PopupMenuItem(
                                    value: 'admin',
                                    child: Text('Set as Administrator'),
                                  ),
                                ],
                                child: AppStatusChip(status: user.role),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateRole(String userId, String role) async {
    try {
      await ref.read(userRepositoryProvider).updateRole(userId, role);
      ref.invalidate(usersProvider);
    } catch (_) {
      if (mounted) _message('Role update failed.');
    }
  }

  Future<void> _createUser(BuildContext context) async {
    final username = TextEditingController();
    final password = TextEditingController();
    var role = 'officer';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create user account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: username,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Temporary password',
                    helperText: 'At least 8 characters',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'officer', child: Text('Officer')),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Administrator'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => role = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await ref
          .read(userRepositoryProvider)
          .create(
            username: username.text.trim(),
            password: password.text,
            role: role,
          );
      ref.invalidate(usersProvider);
      _message('User account created.');
    } catch (_) {
      _message('Could not create user. Check the entered values.');
    } finally {
      username.dispose();
      password.dispose();
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
