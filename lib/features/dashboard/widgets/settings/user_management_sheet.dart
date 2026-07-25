import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

/// User Management & Branch Assignments Sheet.
class UserManagementSheet extends StatefulWidget {
  const UserManagementSheet({super.key});

  @override
  State<UserManagementSheet> createState() => _UserManagementSheetState();
}

class _UserManagementSheetState extends State<UserManagementSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  final List<Map<String, String>> _users = [
    {
      'name': 'Nelson Officer',
      'username': 'nelson.officer',
      'role': 'Loan Officer',
      'branch': 'Central Branch',
      'status': 'Active',
    },
    {
      'name': 'Sarah Jenkins',
      'username': 'sarah.mgr',
      'role': 'Branch Manager',
      'branch': 'Central Branch',
      'status': 'Active',
    },
    {
      'name': 'Admin Supervisor',
      'username': 'admin.sys',
      'role': 'Administrator',
      'branch': 'Headquarters',
      'status': 'Active',
    },
    {
      'name': 'Mark Santos',
      'username': 'mark.collector',
      'role': 'Collection Officer',
      'branch': 'North Branch',
      'status': 'Active',
    },
    {
      'name': 'Elena Rostova',
      'username': 'elena.cashier',
      'role': 'Cashier',
      'branch': 'Central Branch',
      'status': 'Disabled',
    },
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filteredUsers = _users.where((u) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return u['name']!.toLowerCase().contains(q) ||
          u['username']!.toLowerCase().contains(q) ||
          u['role']!.toLowerCase().contains(q);
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
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Icon(Icons.people_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'User Management & Access Control',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // User Summary Cards
            Row(
              children: const [
                Expanded(
                  child: AppMetricCard(
                    label: 'Total Users',
                    value: '5',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: AppMetricCard(
                    label: 'Active Officers',
                    value: '4 Active',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppSearchBar(
              controller: _searchCtrl,
              hintText: 'Search user by name, username, or role...',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredUsers.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.person_off_outlined,
                      title: 'No Users Found',
                      description:
                          'No active staff accounts match your search filter.',
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: filteredUsers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final u = filteredUsers[index];
                        final isActive = u['status'] == 'Active';

                        return AppCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                child: Text(
                                  u['name']![0],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u['name']!,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      '@${u['username']} · ${u['branch']}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        AppStatusChip(status: u['role']!),
                                        const SizedBox(width: 6),
                                        AppStatusChip(
                                          status: u['status']!,
                                          isCompact: true,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (action) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '$action action performed for ${u['name']}',
                                      ),
                                    ),
                                  );
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'Edit Role',
                                    child: Text('Edit Role & Branch'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'Reset Password',
                                    child: Text('Reset Password'),
                                  ),
                                  PopupMenuItem(
                                    value: isActive ? 'Disable' : 'Activate',
                                    child: Text(
                                      isActive
                                          ? 'Disable User'
                                          : 'Activate User',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
