import 'package:flutter/material.dart';
import '../domain/borrower_model.dart';

/// Card displaying emergency contact, registered guarantor / co-maker, and map location placeholder.
class BorrowerEmergencyGuarantorCard extends StatelessWidget {
  final Borrower borrower;

  const BorrowerEmergencyGuarantorCard({super.key, required this.borrower});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final phone = borrower.phone.isNotEmpty ? borrower.phone : 'Not provided';
    const address = 'Primary Field Location Address';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.contact_phone_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Guarantor & Location Details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            // Guarantor Row
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.security_outlined,
                  color: colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              title: const Text('Registered Co-Maker / Guarantor'),
              subtitle: Text('Co-Maker · Phone: $phone'),
              trailing: IconButton.filledTonal(
                icon: const Icon(Icons.call, size: 16),
                tooltip: 'Call Guarantor',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Calling guarantor ($phone)...')),
                  );
                },
              ),
            ),
            const Divider(height: 16),
            // Location Address Map Placeholder
            Row(
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verified Field Address',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(address, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening GPS navigation map...'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.navigation_outlined, size: 14),
                  label: const Text('Map', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
