import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/local_json_cache.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/offline_sync_service.dart';
import 'officer_note.dart';

class NotesRepository {
  const NotesRepository(this._dio, this._sync, this._cache);
  final Dio _dio;
  final OfflineSyncService _sync;
  final LocalJsonCache _cache;

  String _key(String borrowerId, String? loanId) =>
      'notes:$borrowerId:${loanId ?? ''}';

  Future<List<Note>> list(String borrowerId, {String? loanId}) async {
    final key = _key(borrowerId, loanId);
    final cached = await _cache.read(key);
    unawaited(_refresh(borrowerId, loanId));
    final deleted = await _cache.read('notes:deleted');
    final deletedIds = deleted is List
        ? deleted.cast<String>().toSet()
        : <String>{};
    return (cached is List ? cached : const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .where((row) => !deletedIds.contains(row['id']))
        .map(Note.fromJson)
        .toList();
  }

  Future<void> _refresh(String borrowerId, String? loanId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        loanId == null
            ? ApiEndpoints.borrowerNotes(borrowerId)
            : ApiEndpoints.loanNotes(borrowerId, loanId),
      );
      await _cache.write(_key(borrowerId, loanId), response.data ?? const []);
    } catch (_) {}
  }

  Future<void> create(
    String borrowerId, {
    String? loanId,
    required String content,
    required String category,
  }) async {
    final endpoint = loanId == null
        ? ApiEndpoints.borrowerNotes(borrowerId)
        : ApiEndpoints.loanNotes(borrowerId, loanId);
    final payload = {'content': content.trim(), 'category': category};
    final localId = const Uuid().v4();
    final key = _key(borrowerId, loanId);
    final cached = await _cache.read(key);
    final rows = cached is List ? List<dynamic>.from(cached) : <dynamic>[];
    rows.insert(0, {
      'id': localId,
      'borrowerId': borrowerId,
      'loanId': loanId,
      'authorName': 'Owner',
      'category': category,
      'content': content.trim(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'canDelete': true,
    });
    await _cache.write(key, rows);
    await _sync.enqueue(
      endpoint: endpoint,
      method: 'POST',
      payload: payload,
      entityType: loanId == null ? 'borrower_note' : 'loan_note',
      entityLocalId: localId,
      operationType: 'create',
      dependencyIds: [borrowerId, ?loanId],
    );
    unawaited(_sync.drainQueue());
  }

  Future<void> delete(String noteId) async {
    final endpoint = ApiEndpoints.note(noteId);
    final deleted = await _cache.read('notes:deleted');
    final ids = deleted is List ? deleted.cast<String>().toSet() : <String>{};
    ids.add(noteId);
    await _cache.write('notes:deleted', ids.toList());
    await _sync.enqueue(
      endpoint: endpoint,
      method: 'DELETE',
      payload: const {},
      entityType: 'note',
      entityLocalId: noteId,
      operationType: 'delete',
    );
    unawaited(_sync.drainQueue());
  }
}

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(
    ref.watch(apiClientProvider),
    ref.watch(offlineSyncServiceProvider),
    ref.watch(localJsonCacheProvider),
  );
});
