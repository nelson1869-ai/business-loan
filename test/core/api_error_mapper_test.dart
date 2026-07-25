import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/network/api_error_mapper.dart';

void main() {
  DioException error({int? status, Object? data, DioExceptionType? type}) {
    final request = RequestOptions(path: '/test');
    return DioException(
      requestOptions: request,
      type: type ?? DioExceptionType.badResponse,
      response: status == null
          ? null
          : Response<dynamic>(
              requestOptions: request,
              statusCode: status,
              data: data,
            ),
    );
  }

  test('maps connectivity and timeout failures', () {
    expect(
      ApiErrorMapper.message(error(type: DioExceptionType.connectionError)),
      contains('online connection'),
    );
    expect(
      ApiErrorMapper.message(error(type: DioExceptionType.connectionTimeout)),
      contains('too long'),
    );
  });

  test('maps supported HTTP statuses without exposing objects', () {
    expect(ApiErrorMapper.message(error(status: 401)), contains('session'));
    expect(ApiErrorMapper.message(error(status: 403)), contains('permission'));
    expect(ApiErrorMapper.message(error(status: 413)), contains('too large'));
    expect(
      ApiErrorMapper.message(error(status: 500, data: {'trace': 'secret'})),
      isNot(contains('secret')),
    );
  });

  test('preserves bounded safe validation detail', () {
    expect(
      ApiErrorMapper.message(
        error(
          status: 422,
          data: {'detail': 'Promise date cannot be in the past'},
        ),
      ),
      'Promise date cannot be in the past',
    );
  });
}
