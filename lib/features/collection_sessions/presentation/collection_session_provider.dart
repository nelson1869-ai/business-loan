import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/collection_session_repository.dart';
import '../domain/collection_session.dart';

final collectionSessionsProvider =
    FutureProvider.autoDispose<List<CollectionSession>>((ref) {
      return ref.watch(collectionSessionRepositoryProvider).list();
    });
