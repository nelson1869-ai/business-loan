import 'package:flutter/material.dart';

/// Card collecting payment details (Method, Collector ID, Date, Notes).
class PaymentCollectionDetailsCard extends StatefulWidget {
  final String dateLabel;
  final TextEditingController noteController;
  final bool working;
  final VoidCallback onPickDate;
  final VoidCallback onFieldChange;

  const PaymentCollectionDetailsCard({
    super.key,
    required this.dateLabel,
    required this.noteController,
    required this.working,
    required this.onPickDate,
    required this.onFieldChange,
  });

  @override
  State<PaymentCollectionDetailsCard> createState() =>
      _PaymentCollectionDetailsCardState();
}

class _PaymentCollectionDetailsCardState
    extends State<PaymentCollectionDetailsCard> {
  String _selectedMethod = 'Cash';

  final _methods = const [
    DropdownMenuItem(value: 'Cash', child: Text('💵 Cash')),
    DropdownMenuItem(value: 'GCash', child: Text('📱 GCash / E-Wallet')),
    DropdownMenuItem(value: 'Bank Transfer', child: Text('🏦 Bank Transfer')),
    DropdownMenuItem(value: 'Check', child: Text('📄 Check')),
    DropdownMenuItem(value: 'Other', child: Text('💳 Other')),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  Icons.tune_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Collection & Transaction Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Payment Method Dropdown
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMethod,
                  isExpanded: true,
                  items: _methods,
                  onChanged: widget.working
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() => _selectedMethod = val);
                          }
                        },
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Collection Date ListTile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Collection Date'),
              subtitle: Text(widget.dateLabel),
              trailing: const Icon(Icons.edit_calendar),
              onTap: widget.working ? null : widget.onPickDate,
            ),
            const SizedBox(height: 8),
            // Notes Input
            TextField(
              controller: widget.noteController,
              enabled: !widget.working,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Collection Notes / Remarks (optional)',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => widget.onFieldChange(),
            ),
          ],
        ),
      ),
    );
  }
}
