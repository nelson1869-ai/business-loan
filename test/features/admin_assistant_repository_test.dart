import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/core/security/encryption_service.dart';
import 'package:lending_nelson/features/dashboard/data/admin_assistant_repository.dart';
import 'package:lending_nelson/features/dashboard/data/local_admin_assistant_service.dart';

void main() {
  test('questions go only to protected FastAPI endpoint', () async {
    final adapter = _AssistantAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'))
      ..httpClientAdapter = adapter;
    final repository = AdminAssistantRepository(
      dio,
      _FakeLocalAssistantService(),
    );

    final reply = await repository.ask(
      'How much does Juan Dela Cruz owe?',
      selectedBorrowerId: '00000000-0000-4000-8000-000000000001',
    );

    expect(adapter.request?.path, '/api/v1/admin-assistant/questions');
    expect(adapter.request?.uri.host, 'localhost');
    expect(
      adapter.request?.data['selectedBorrowerId'],
      '00000000-0000-4000-8000-000000000001',
    );
    expect(reply.answerSource, 'local');
  });

  test('transport failure uses local deterministic service', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'))
      ..httpClientAdapter = _FailingAdapter();
    final repository = AdminAssistantRepository(
      dio,
      _FakeLocalAssistantService(),
    );

    final reply = await repository.ask('portfolio summary');

    expect(reply.answer, 'Offline verified answer');
    expect(reply.answerSource, 'offline');
  });
}

class _FakeLocalAssistantService extends LocalAdminAssistantService {
  _FakeLocalAssistantService()
    : super(DatabaseService(), EncryptionService(const FlutterSecureStorage()));

  @override
  Future<AdminAssistantReply> answer(
    String message, {
    String? selectedBorrowerId,
    int offset = 0,
  }) async => const AdminAssistantReply(
    answer: 'Offline verified answer',
    records: [],
    asOf: '2026-07-28',
    source: 'Synchronized local database',
    disclaimer: 'Offline result may be stale.',
    answerSource: 'offline',
  );
}

class _AssistantAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'intent': 'borrowerBalance',
        'answer': 'Verified local answer',
        'metrics': <String, dynamic>{},
        'records': <dynamic>[],
        'asOf': '2026-07-28',
        'generatedAt': '2026-07-28T12:00:00Z',
        'answerSource': 'local',
        'aiUsed': false,
        'aiStatus': 'skipped',
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    );
  }

  @override
  void close({bool force = false}) {}
}
