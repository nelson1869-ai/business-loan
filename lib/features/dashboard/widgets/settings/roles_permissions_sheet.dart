import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

class RolesPermissionsSheet extends StatelessWidget {
  const RolesPermissionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Supported Roles',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Permissions are enforced by the backend. Custom permission '
            'matrices are not currently supported.',
          ),
          SizedBox(height: 16),
          AppSectionCard(
            title: 'Administrator',
            icon: Icons.admin_panel_settings_outlined,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle_outline),
                title: Text(
                  'Full access: loan approval/disbursement, registration review, user management, suspension, and reporting.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline),
                title: Text(
                  'Dual-Control Rule: Cannot approve own loan applications or registration requests.',
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          AppSectionCard(
            title: 'Officer',
            icon: Icons.badge_outlined,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle_outline),
                title: Text(
                  'Creates/manages borrowers, loan applications, payment collections, and reconciliations.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.block_outlined),
                title: Text(
                  'Cannot approve loans, approve borrower registrations, or manage staff user accounts.',
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          AppSectionCard(
            title: 'Emergency Owner (Super-Admin)',
            icon: Icons.security_outlined,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.lock_outline),
                title: Text(
                  'Internal recovery & super-admin role. Preserved for system recovery and omitted from user creation options.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
