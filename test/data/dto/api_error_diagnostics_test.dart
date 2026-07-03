import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/error/error_diagnostics.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/dto/api_envelope.dart';

void main() {
  test(
    'business failure preserves request metadata and backend code',
    () async {
      final result = await guardApi<Object?>(
        () async => Response<dynamic>(
          requestOptions: RequestOptions(
            path: '/api/v1/profile',
            method: 'POST',
            headers: {'X-Request-ID': 'client-request'},
          ),
          statusCode: 200,
          headers: Headers.fromMap({
            'x-request-id': ['server-request'],
          }),
          data: {'code': 42201, 'message': '字段校验失败', 'data': null},
        ),
        (data) => data,
      );

      final error = (result as Failure<Object?>).error;
      expect(error, isA<ValidationException>());
      expect(error.message, '字段校验失败');
      expect(error.diagnostics?.requestId, 'server-request');
      expect(error.diagnostics?.method, 'POST');
      expect(error.diagnostics?.path, '/api/v1/profile');
      expect(error.diagnostics?.backendCode, '42201');
      expect(error.diagnostics?.httpStatus, 200);
    },
  );

  test(
    'decode failure retains cause and a redacted response preview',
    () async {
      final result = await guardApi<String>(
        () async => Response<dynamic>(
          requestOptions: RequestOptions(
            path: '/api/v1/profile',
            method: 'GET',
            headers: {'X-Request-ID': 'request-1'},
          ),
          statusCode: 200,
          data: {
            'code': 0,
            'message': 'ok',
            'data': {'access_token': 'secret-token', 'value': 'unexpected'},
          },
        ),
        (_) => throw const FormatException('missing profile.name'),
      );

      final error = (result as Failure<String>).error;
      expect(error, isA<ServerException>());
      expect(error.diagnostics?.cause, contains('missing profile.name'));
      expect(error.diagnostics?.responsePreview, contains('[REDACTED]'));
      expect(
        error.diagnostics?.responsePreview,
        isNot(contains('secret-token')),
      );
    },
  );

  test(
    'bad HTTP responses preserve status, backend message and request ID',
    () {
      final request = RequestOptions(
        path: '/api/v1/history',
        method: 'DELETE',
        headers: {'X-Request-ID': 'request-409'},
      );
      final exception = DioException.badResponse(
        statusCode: 409,
        requestOptions: request,
        response: Response<dynamic>(
          requestOptions: request,
          statusCode: 409,
          data: {'code': 40901, 'message': '版本冲突', 'data': null},
        ),
      );

      final error = mapDioException(exception);
      expect(error, isA<ConflictException>());
      expect(error.message, '版本冲突');
      expect(error.diagnostics?.httpStatus, 409);
      expect(error.diagnostics?.backendCode, '40901');
      expect(error.diagnostics?.requestId, 'request-409');
    },
  );

  test('auth interceptor AppException is not collapsed to unknown', () {
    final request = RequestOptions(path: '/api/v1/profile', method: 'GET');
    const original = UnauthorizedException(message: '匿名身份创建失败');
    final mapped = mapDioException(
      DioException(
        requestOptions: request,
        type: DioExceptionType.unknown,
        error: original,
      ),
    );

    expect(mapped, isA<UnauthorizedException>());
    expect(mapped.message, '匿名身份创建失败');
    expect(mapped.diagnostics?.path, '/api/v1/profile');
  });

  test('response previews are truncated and redact private values', () {
    final preview = sanitizedResponsePreview({
      'password': 'do-not-show',
      'contact': '13800000000',
      'payload': List.filled(5000, 'x').join(),
    });

    expect(preview, isNot(contains('do-not-show')));
    expect(preview, isNot(contains('13800000000')));
    expect(preview, contains('[REDACTED]'));
    expect(preview!.length, lessThanOrEqualTo(4110));
    expect(preview, endsWith('…（已截断）'));
  });
}
