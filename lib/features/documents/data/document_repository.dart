import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_json_cache.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/offline_sync_service.dart';
import '../domain/app_document.dart';

class DocumentRepository {
  const DocumentRepository(this._dio, this._sync, this._cache);

  final Dio _dio;
  final OfflineSyncService _sync;
  final LocalJsonCache _cache;

  String _key(String borrowerId, String? loanId) =>
      'documents:$borrowerId:${loanId ?? ''}';

  Future<List<AppDocument>> load({
    required String borrowerId,
    String? loanId,
  }) async {
    final cached = await _cache.read(_key(borrowerId, loanId));
    unawaited(_refresh(borrowerId, loanId));
    final deleted = await _cache.read('documents:deleted');
    final deletedIds = deleted is List
        ? deleted.cast<String>().toSet()
        : <String>{};
    return (cached is List ? cached : const <dynamic>[])
        .where((item) => !deletedIds.contains((item as Map)['id']))
        .map(
          (item) =>
              AppDocument.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<void> _refresh(String borrowerId, String? loanId) async {
    final endpoint = loanId == null
        ? ApiEndpoints.borrowerDocuments(borrowerId)
        : ApiEndpoints.loanDocuments(borrowerId, loanId);
    try {
      final response = await _dio.get<List<dynamic>>(endpoint);
      await _cache.write(
        _key(borrowerId, loanId),
        response.data ?? const <dynamic>[],
      );
    } catch (_) {}
  }

  Future<void> upload({
    required String borrowerId,
    required String title,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
    String? loanId,
  }) async {
    final endpoint = loanId == null
        ? ApiEndpoints.borrowerDocuments(borrowerId)
        : ApiEndpoints.loanDocuments(borrowerId, loanId);
    final payload = {
      'title': title,
      'fileName': fileName,
      'contentType': contentType,
      'contentBase64': base64Encode(bytes),
    };
    final localId = const Uuid().v4();
    final key = _key(borrowerId, loanId);
    final cached = await _cache.read(key);
    final rows = cached is List ? List<dynamic>.from(cached) : <dynamic>[];
    rows.insert(0, {
      'id': localId,
      'borrowerId': borrowerId,
      'loanId': loanId,
      'uploadedByUserId': 'local-officer',
      'title': title,
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': bytes.length,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'canDelete': true,
    });
    await _cache.write(key, rows);
    await _cache.write('document-content:$localId', base64Encode(bytes));
    await _sync.enqueue(
      endpoint: endpoint,
      method: 'POST',
      payload: payload,
      entityType: 'document',
      entityLocalId: localId,
      operationType: 'create',
      dependencyIds: [borrowerId, ?loanId],
    );
    unawaited(_sync.drainQueue());
  }

  Future<Uint8List> download(String documentId) async {
    final cached = await _cache.read('document-content:$documentId');
    if (cached is String) return base64Decode(cached);
    final response = await _dio.get<List<int>>(
      ApiEndpoints.documentContent(documentId),
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const <int>[]);
  }

  Future<void> delete(String documentId) async {
    final endpoint = ApiEndpoints.document(documentId);
    final deleted = await _cache.read('documents:deleted');
    final ids = deleted is List ? deleted.cast<String>().toSet() : <String>{};
    ids.add(documentId);
    await _cache.write('documents:deleted', ids.toList());
    await _sync.enqueue(
      endpoint: endpoint,
      method: 'DELETE',
      payload: const {},
      entityType: 'document',
      entityLocalId: documentId,
      operationType: 'delete',
    );
    unawaited(_sync.drainQueue());
  }
}

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(
    ref.watch(apiClientProvider),
    ref.watch(offlineSyncServiceProvider),
    ref.watch(localJsonCacheProvider),
  );
});
