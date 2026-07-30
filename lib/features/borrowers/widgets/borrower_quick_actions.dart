import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../borrower_communication/presentation/borrower_communication_provider.dart';
import '../../borrower_communication/presentation/send_to_borrower_sheet.dart';
import '../../loans/domain/models/loan.dart';
import '../domain/borrower_model.dart';

/// Large Material 3 Quick Actions Bar for Borrower Profile.
class BorrowerQuickActions extends StatelessWidget {
  final Borrower borrower;
  final String? activeLoanId;
  final Loan? activeLoan;
  final VoidCallback? onAddNote;

  const BorrowerQuickActions({
    super.key,
    required this.borrower,
    this.activeLoanId,
    this.activeLoan,
    this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        if (activeLoanId != null)
          FilledButton.icon(
            onPressed: () => context.push('/loans/$activeLoanId/payments'),
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text('Record Payment'),
          ),
        FilledButton.tonalIcon(
          onPressed: () => context.push(
            '/borrowers/${borrower.id}/loans/new',
            extra: borrower,
          ),
          icon: const Icon(Icons.add_card, size: 18),
          label: const Text('Create Loan'),
        ),
        if (onAddNote != null)
          OutlinedButton.icon(
            onPressed: onAddNote,
            icon: const Icon(Icons.note_add_outlined, size: 18),
            label: const Text('Add Note'),
          ),
        OutlinedButton.icon(
          onPressed: () => SendToBorrowerSheet.show(
            context,
            BorrowerCommunicationRequest(
              borrowerId: borrower.id,
              borrower: borrower,
              loan: activeLoan,
            ),
          ),
          icon: const Icon(Icons.send_to_mobile_outlined, size: 18),
          label: const Text('Send to Borrower'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Calling ${borrower.fullName}...')),
            );
          },
          icon: const Icon(Icons.call_outlined, size: 18),
          label: const Text('Call Borrower'),
        ),
      ],
    );
  }
}
