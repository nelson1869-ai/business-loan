import 'package:flutter/material.dart';

import '../../../../documents/widgets/document_list_view.dart';

class LoanDocumentsTab extends StatelessWidget {
  const LoanDocumentsTab({
    super.key,
    required this.borrowerId,
    required this.loanId,
  });

  final String borrowerId;
  final String loanId;

  @override
  Widget build(BuildContext context) {
    return DocumentListView(borrowerId: borrowerId, loanId: loanId);
  }
}
