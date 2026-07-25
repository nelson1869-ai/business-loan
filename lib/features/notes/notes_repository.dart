import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import 'officer_note.dart';

class NotesRepository {
  const NotesRepository(this._dio);
  final Dio _dio;

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
    await _dio.post<void>(
      loanId == null
          ? ApiEndpoints.borrowerNotes(borrowerId)
          : ApiEndpoints.loanNotes(borrowerId, loanId),
      data: {'content': content.trim(), 'category': category},
    );
  }

  Future<void> delete(String noteId) =>
      _dio.delete<void>(ApiEndpoints.note(noteId));
}

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(ref.watch(apiClientProvider));
});
