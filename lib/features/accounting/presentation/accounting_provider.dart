import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/accounting_repository.dart';
import '../domain/journal_entry.dart';

final journalsProvider = FutureProvider.autoDispose<List<JournalEntry>>((ref) {
  return ref.watch(accountingRepositoryProvider).listJournals();
});
