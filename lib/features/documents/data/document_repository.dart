import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/app_document.dart';

class DocumentRepository {
  const DocumentRepository(this._dio);

  final Dio _dio;

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
    await _dio.post<void>(
      endpoint,
      data: {
        'title': title,
        'fileName': fileName,
        'contentType': contentType,
        'contentBase64': base64Encode(bytes),
      },
    );
  }

  Future<Uint8List> download(String documentId) async {
    final response = await _dio.get<List<int>>(
      ApiEndpoints.documentContent(documentId),
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const <int>[]);
  }

  Future<void> delete(String documentId) async {
    await _dio.delete<void>(ApiEndpoints.document(documentId));
  }
}

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(ref.watch(apiClientProvider));
});
