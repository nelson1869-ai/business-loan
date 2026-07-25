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
                title: Text('Manage user accounts and roles'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle_outline),
                title: Text('Manage business presentation settings'),
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
                title: Text('Operate lending and collection workflows'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.block_outlined),
                title: Text('Cannot administer users or system settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
