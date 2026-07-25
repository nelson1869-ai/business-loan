import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

/// Business Profile & Loan Configuration Sheet.
class BusinessLoanConfigSheet extends StatefulWidget {
  const BusinessLoanConfigSheet({super.key});

  @override
  State<BusinessLoanConfigSheet> createState() =>
      _BusinessLoanConfigSheetState();
}

class _BusinessLoanConfigSheetState extends State<BusinessLoanConfigSheet> {
  final _businessNameCtrl = TextEditingController(
    text: 'Lending Nelson Microfinance',
  );
  final _currencyCtrl = TextEditingController(text: 'PHP (₱)');
  final _receiptFooterCtrl = TextEditingController(
    text: 'Thank you for your prompt payment!',
  );
  bool _gracePeriodEnabled = true;
  bool _autoPenalties = false;

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _currencyCtrl.dispose();
    _receiptFooterCtrl.dispose();
    super.dispose();
  }

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
                Icon(Icons.storefront_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Business & Lending Configuration',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Financial Disclaimer Banner
            AppCard(
              margin: EdgeInsets.zero,
              borderColor: Colors.amber.shade700.withValues(alpha: 0.4),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber.shade800,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Changes to interest calculations or penalty rules affect future loan contracts only.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Business Details Card
            AppSectionCard(
              title: 'Business Profile Details',
              icon: Icons.business,
              children: [
                TextField(
                  controller: _businessNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Business Name',
                    prefixIcon: Icon(Icons.apartment),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _currencyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Operating Currency Symbol',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _receiptFooterCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Thermal Receipt Footer Text',
                    prefixIcon: Icon(Icons.receipt_long),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Lending Parameters Card
            AppSectionCard(
              title: 'Lending & Interest Terms',
              icon: Icons.percent,
              children: [
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable 3-Day Grace Period'),
                  subtitle: const Text(
                    'No late penalties incurred during 3-day grace period after due date',
                  ),
                  value: _gracePeriodEnabled,
                  onChanged: (val) => setState(() => _gracePeriodEnabled = val),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Automatic Late Fee Allocation'),
                  subtitle: const Text(
                    'Automatically allocate payments to late fees before principal',
                  ),
                  value: _autoPenalties,
                  onChanged: (val) => setState(() => _autoPenalties = val),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Business configuration saved successfully'),
                  ),
                );
              },
              icon: const Icon(Icons.save),
              label: const Text('Save Business Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
