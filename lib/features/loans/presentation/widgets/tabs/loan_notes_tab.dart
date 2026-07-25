import 'package:flutter/material.dart';

import '../../../../borrowers/widgets/tabs/notes_tab_view.dart';

/// Loan notes reuse the persisted note UI with a loan-specific scope.
class LoanNotesTab extends StatelessWidget {
  const LoanNotesTab({
    super.key,
    required this.borrowerId,
    required this.loanId,
  });

  final String borrowerId;
  final String loanId;

  @override
  Widget build(BuildContext context) {
    return NotesTabView(borrowerId: borrowerId, loanId: loanId);
  }
}
