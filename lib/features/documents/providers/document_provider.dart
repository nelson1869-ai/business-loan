import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/document_repository.dart';
import '../domain/app_document.dart';

typedef DocumentScope = ({String borrowerId, String? loanId});

final documentsProvider = FutureProvider.autoDispose
    .family<List<AppDocument>, DocumentScope>((ref, scope) {
      return ref
          .watch(documentRepositoryProvider)
          .load(borrowerId: scope.borrowerId, loanId: scope.loanId);
    });
