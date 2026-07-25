import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_error_mapper.dart';
import '../../core/network/offline_sync_service.dart';
import 'officer_note.dart';

class NotesRepository {
  const NotesRepository(this._dio, this._sync);
  final Dio _dio;
  final OfflineSyncService _sync;

  Future<List<OfficerNote>> list(String borrowerId, {String? loanId}) async {
    final response = await _dio.get<List<dynamic>>(
      loanId == null
          ? ApiEndpoints.borrowerNotes(borrowerId)
          : ApiEndpoints.loanNotes(borrowerId, loanId),
    );
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(OfficerNote.fromJson)
        .toList();
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
    try {
      await _dio.post<void>(endpoint, data: payload);
    } catch (error) {
      if (!ApiErrorMapper.isOfflineFailure(error)) rethrow;
      await _sync.enqueue(
        endpoint: endpoint,
        method: 'POST',
        payload: payload,
        entityType: loanId == null ? 'borrower_note' : 'loan_note',
        entityLocalId:
            '${borrowerId}_${loanId ?? 'borrower'}_'
            '${sha256.convert(utf8.encode(content.trim()))}',
        operationType: 'create',
        dependencyIds: [borrowerId, ?loanId],
      );
    }
  }

  Future<void> delete(String noteId) async {
    final endpoint = ApiEndpoints.note(noteId);
    try {
      await _dio.delete<void>(endpoint);
    } catch (error) {
      if (!ApiErrorMapper.isOfflineFailure(error)) rethrow;
      await _sync.enqueue(
        endpoint: endpoint,
        method: 'DELETE',
        payload: const {},
        entityType: 'note',
        entityLocalId: noteId,
        operationType: 'delete',
      );
    }
  }
}

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(
    ref.watch(apiClientProvider),
    ref.watch(offlineSyncServiceProvider),
  );
});
