import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/network/offline_sync_service.dart';
import '../domain/app_document.dart';

class DocumentRepository {
  const DocumentRepository(this._dio, this._sync);

  final Dio _dio;
  final OfflineSyncService _sync;

  Future<List<AppDocument>> load({
    required String borrowerId,
    String? loanId,
  }) async {
    final endpoint = loanId == null
        ? ApiEndpoints.borrowerDocuments(borrowerId)
        : ApiEndpoints.loanDocuments(borrowerId, loanId);
    final response = await _dio.get<List<dynamic>>(endpoint);
    return (response.data ?? const <dynamic>[])
        .map(
          (item) =>
              AppDocument.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
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
    try {
      await _dio.post<void>(endpoint, data: payload);
    } catch (error) {
      if (!ApiErrorMapper.isOfflineFailure(error)) rethrow;
      await _sync.enqueue(
        endpoint: endpoint,
        method: 'POST',
        payload: payload,
        entityType: 'document',
        entityLocalId:
            '${borrowerId}_${loanId ?? 'borrower'}_${sha256.convert(bytes)}',
        operationType: 'create',
        dependencyIds: [borrowerId, ?loanId],
      );
    }
  }

  Future<Uint8List> download(String documentId) async {
    final response = await _dio.get<List<int>>(
      ApiEndpoints.documentContent(documentId),
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const <int>[]);
  }

  Future<void> delete(String documentId) async {
    final endpoint = ApiEndpoints.document(documentId);
    try {
      await _dio.delete<void>(endpoint);
    } catch (error) {
      if (!ApiErrorMapper.isOfflineFailure(error)) rethrow;
      await _sync.enqueue(
        endpoint: endpoint,
        method: 'DELETE',
        payload: const {},
        entityType: 'document',
        entityLocalId: documentId,
        operationType: 'delete',
      );
    }
  }
}

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(
    ref.watch(apiClientProvider),
    ref.watch(offlineSyncServiceProvider),
  );
});
