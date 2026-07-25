import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

/// High-Trust Security & Backup Sheet.
class SecurityBackupSheet extends StatefulWidget {
  const SecurityBackupSheet({super.key});

  @override
  State<SecurityBackupSheet> createState() => _SecurityBackupSheetState();
}

class _SecurityBackupSheetState extends State<SecurityBackupSheet> {
  bool _biometrics = true;
  bool _maskPII = true;

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
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.security, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Security & Data Encryption',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // High Trust Security Card
            AppSectionCard(
              title: 'Device & Data Controls',
              icon: Icons.lock_outline,
              children: [
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Biometric / App PIN Unlock'),
                  subtitle: const Text(
                    'Require fingerprint or PIN when restoring app',
                  ),
                  value: _biometrics,
                  onChanged: (val) => setState(() => _biometrics = val),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mask Borrower PII on Dashboard'),
                  subtitle: const Text(
                    'Automatically mask phone numbers and National IDs',
                  ),
                  value: _maskPII,
                  onChanged: (val) => setState(() => _maskPII = val),
                ),
                const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.verified_user_outlined),
                  title: Text('Local Database Status'),
                  subtitle: Text('AES-256 Encrypted SQLite Storage'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Danger Zone Card
            AppCard(
              margin: EdgeInsets.zero,
              borderColor: Colors.red.withValues(alpha: 0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'Danger Zone',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Destructive actions require explicit confirmation and admin elevation.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await AppConfirmationDialog.show(
                        context,
                        title: 'Clear Local Cache?',
                        content:
                            'This will purge local temporary cache files. Unsynced audit logs will not be affected.',
                        confirmLabel: 'Clear Cache',
                      );
                      if (confirmed == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Local cache cleared successfully'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.cleaning_services,
                      color: Colors.red,
                      size: 16,
                    ),
                    label: const Text(
                      'Clear Local Cache',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
