import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../borrowers/data/borrower_repository.dart';
import '../../loans/data/repositories/local_loan_repository.dart';

/// Modal bottom sheet for single-owner CREATE mode actions.
class CreateActionSheet extends ConsumerWidget {
  const CreateActionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateActionSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_circle,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CREATE MODE',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Create new business records (Saved as Draft/Pending)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // Options — scrollable so it never overflows on small screens
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Create Borrower
                    _CreateOptionTile(
                      icon: Icons.person_add_outlined,
                      color: Colors.blue.shade700,
                      title: 'Create Borrower',
                      subtitle: 'Add new borrower profile and PII',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/borrowers/register');
                      },
                    ),

                    // 2. Create Loan Application
                    _CreateOptionTile(
                      icon: Icons.assignment_add,
                      color: Colors.purple.shade700,
                      title: 'Create Loan Application',
                      subtitle: 'Draft new loan (Pending Review)',
                      onTap: () async {
                        Navigator.pop(context);
                        await _selectBorrowerForLoan(context, ref);
                      },
                    ),

                    // 3. Record Payment
                    _CreateOptionTile(
                      icon: Icons.payments_outlined,
                      color: Colors.green.shade700,
                      title: 'Record Payment',
                      subtitle: 'Log repayment for an active loan',
                      onTap: () async {
                        Navigator.pop(context);
                        await _selectLoanForPayment(context, ref);
                      },
                    ),

                    // 4. Add Guarantor
                    _CreateOptionTile(
                      icon: Icons.shield_outlined,
                      color: Colors.amber.shade800,
                      title: 'Add Guarantor',
                      subtitle: 'Attach guarantor to borrower profile',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/borrowers');
                      },
                    ),

                    // 5. Add Documents
                    _CreateOptionTile(
                      icon: Icons.upload_file_outlined,
                      color: Colors.teal.shade700,
                      title: 'Add Documents',
                      subtitle: 'Upload agreement, ID, or collateral files',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/borrowers');
                      },
                    ),

                    // 6. Add Notes
                    _CreateOptionTile(
                      icon: Icons.note_add_outlined,
                      color: Colors.indigo.shade700,
                      title: 'Add Notes',
                      subtitle: 'Attach remarks or communication logs',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/borrowers');
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _selectBorrowerForLoan(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final repository = ref.read(borrowerRepositoryProvider);
    final borrowers = await repository.getBorrowers();

    if (!context.mounted) return;

    if (borrowers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No borrowers found. Please create a borrower first.'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Borrower for New Loan'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: borrowers.length,
            itemBuilder: (context, index) {
              final b = borrowers[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(b.firstName.isNotEmpty ? b.firstName[0] : 'B'),
                ),
                title: Text('${b.firstName} ${b.lastName}'),
                subtitle: Text(b.phone.isNotEmpty ? b.phone : 'No phone'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  context.push('/borrowers/${b.id}/loans/new', extra: b);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  static Future<void> _selectLoanForPayment(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final repository = ref.read(localLoanRepositoryProvider);
    final loans = await repository.getLoans();

    if (!context.mounted) return;

    if (loans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active loans found for payment.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Loan to Record Payment'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: loans.length,
            itemBuilder: (context, index) {
              final loan = loans[index];
              final amountStr = double.tryParse(loan.originalPrincipal)?.toStringAsFixed(2) ?? loan.originalPrincipal;
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.receipt_long, size: 20),
                ),
                title: Text('Loan #${loan.id.substring(0, 8)} • ₱$amountStr'),
                subtitle: Text('Status: ${loan.status}'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  context.push('/loans/${loan.id}/payments');
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _CreateOptionTile extends StatelessWidget {
  const _CreateOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: onTap,
        ),
      ),
    );
  }
}
