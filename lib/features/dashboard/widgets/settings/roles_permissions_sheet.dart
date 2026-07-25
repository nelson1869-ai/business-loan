import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

/// Roles & Permission Matrix Management Sheet.
class RolesPermissionsSheet extends StatefulWidget {
  const RolesPermissionsSheet({super.key});

  @override
  State<RolesPermissionsSheet> createState() => _RolesPermissionsSheetState();
}

class _RolesPermissionsSheetState extends State<RolesPermissionsSheet> {
  String _selectedRole = 'Loan Officer';

  final List<String> _roles = [
    'Administrator',
    'Branch Manager',
    'Loan Officer',
    'Cashier',
    'Auditor',
  ];

  final Map<String, Map<String, bool>> _permissionMatrix = {
    'Dashboard': {'View': true, 'Export': true, 'Manage': false},
    'Borrowers': {'View': true, 'Create': true, 'Edit': true, 'Delete': false},
    'Loans': {'View': true, 'Create': true, 'Approve': false, 'Delete': false},
    'Payments': {'View': true, 'Collect': true, 'Reverse': false},
    'Audit Logs': {'View': true, 'Export': false, 'Manage': false},
    'Settings': {'View': true, 'Manage': false},
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                Icon(
                  Icons.admin_panel_settings_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Roles & Permission Matrix',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Role Selector Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _roles.map((role) {
                  final isSelected = _selectedRole == role;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppFilterChip(
                      label: role,
                      isSelected: isSelected,
                      onSelected: () => setState(() => _selectedRole = role),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            // Selected Role Header
            AppCard(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primary.withValues(
                      alpha: 0.15,
                    ),
                    child: Icon(
                      Icons.shield,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_selectedRole Capabilities',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getRoleDescription(_selectedRole),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const AppStatusChip(status: 'System Role'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Permission Matrix List
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _permissionMatrix.keys.length,
                itemBuilder: (context, index) {
                  final module = _permissionMatrix.keys.elementAt(index);
                  final actions = _permissionMatrix[module]!;

                  return AppSectionCard(
                    title: '$module Module Permissions',
                    icon: Icons.security_outlined,
                    children: actions.entries.map((entry) {
                      final isAllowed =
                          _selectedRole == 'Administrator' || entry.value;

                      return SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.key),
                        subtitle: Text(
                          isAllowed
                              ? 'Allowed for $_selectedRole'
                              : 'Restricted capability',
                        ),
                        value: isAllowed,
                        onChanged: _selectedRole == 'Administrator'
                            ? null
                            : (val) {
                                setState(() {
                                  _permissionMatrix[module]![entry.key] = val;
                                });
                              },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'Administrator':
        return 'Full unrestricted system configuration & user access control.';
      case 'Branch Manager':
        return 'Branch operations, loan approvals, officer oversight, & reporting.';
      case 'Loan Officer':
        return 'Borrower registration, loan creation, collection, & field visits.';
      case 'Cashier':
        return 'Payment collection, receipt issuance, & cash drawer logging.';
      case 'Auditor':
        return 'Read-only access to portfolio analytics & local audit logs.';
      default:
        return 'Standard system permissions.';
    }
  }
}
