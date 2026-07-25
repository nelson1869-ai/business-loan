import 'package:flutter/material.dart';

import '../../../documents/widgets/document_list_view.dart';

class DocumentsTabView extends StatelessWidget {
  const DocumentsTabView({super.key, required this.borrowerId});

  final String borrowerId;

  @override
  Widget build(BuildContext context) {
    return DocumentListView(borrowerId: borrowerId);
  }
}
