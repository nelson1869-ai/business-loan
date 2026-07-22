import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/borrowers/data/remote_borrower_repository.dart';
import 'package:lending_nelson/features/borrowers/domain/borrower_model.dart';

void main() {
  const borrower = Borrower(
    id: '00000000-0000-4000-8000-000000000001',
    firstName: 'Jane',
    lastName: 'Doe',
    nationalId: '12345678',
    phone: '+254712345678',
    dateOfBirth: '1990-01-01',
    status: 'Pending',
    createdAt: '2026-01-01T00:00:00Z',
  );

  test('missing legacy borrower is created before a related write', () async {
    final adapter = _BorrowerAdapter(existing: false);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'))
      ..httpClientAdapter = adapter;
    final repository = RemoteBorrowerRepository(dio);

    await repository.ensureBorrowerExists(borrower);

    expect(adapter.methods, <String>['GET', 'POST']);
    expect(adapter.paths, <String>[
      '/api/v1/borrowers/${borrower.id}',
      '/api/v1/borrowers',
    ]);
    expect(adapter.postedData?['id'], borrower.id);
  });

  test('existing remote borrower is not created again', () async {
    final adapter = _BorrowerAdapter(existing: true);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'))
      ..httpClientAdapter = adapter;

    await RemoteBorrowerRepository(dio).ensureBorrowerExists(borrower);

    expect(adapter.methods, <String>['GET']);
  });
}

class _BorrowerAdapter implements HttpClientAdapter {
  _BorrowerAdapter({required this.existing});

  final bool existing;
  final List<String> methods = <String>[];
  final List<String> paths = <String>[];
  Map<String, dynamic>? postedData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    methods.add(options.method);
    paths.add(options.path);
    if (options.method == 'POST') {
      postedData = Map<String, dynamic>.from(
        options.data as Map<dynamic, dynamic>,
      );
      return _jsonResponse(<String, dynamic>{}, 201);
    }
    if (!existing) {
      return _jsonResponse(<String, dynamic>{
        'detail': 'Borrower not found',
      }, 404);
    }
    return _jsonResponse(<String, dynamic>{'id': 'borrower'}, 200);
  }

  ResponseBody _jsonResponse(Object body, int statusCode) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
