import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notes_repository.dart';
import 'officer_note.dart';

typedef NotesScope = ({String borrowerId, String? loanId});

final notesProvider = FutureProvider.autoDispose
    .family<List<Note>, NotesScope>((ref, scope) {
      return ref
          .watch(notesRepositoryProvider)
          .list(scope.borrowerId, loanId: scope.loanId);
    });
