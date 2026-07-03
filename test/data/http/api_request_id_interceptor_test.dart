import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/http/api_request_id_interceptor.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.onRequest);

  final void Function(RequestOptions options) onRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest(options);
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'message': 'ok', 'data': {}}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('adds a UUID request ID when none is supplied', () async {
    RequestOptions? captured;
    final dio = Dio()
      ..interceptors.add(ApiRequestIdInterceptor())
      ..httpClientAdapter = _FakeAdapter((options) => captured = options);

    await dio.get<dynamic>('https://api.example.com/api/v1/profile');

    final requestId = captured!.headers[apiRequestIdHeader]?.toString();
    expect(requestId, isNotNull);
    expect(
      requestId,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-')),
    );
  });

  test('reuses Idempotency-Key for conversation mutations', () async {
    RequestOptions? captured;
    final dio = Dio()
      ..interceptors.add(ApiRequestIdInterceptor())
      ..httpClientAdapter = _FakeAdapter((options) => captured = options);

    await dio.post<dynamic>(
      'https://api.example.com/api/v1/chat/sessions/s1/turns',
      options: Options(headers: {'Idempotency-Key': 'turn-request-id'}),
    );

    expect(captured!.headers[apiRequestIdHeader], 'turn-request-id');
  });

  test('keeps an explicitly supplied request ID', () async {
    RequestOptions? captured;
    final dio = Dio()
      ..interceptors.add(ApiRequestIdInterceptor())
      ..httpClientAdapter = _FakeAdapter((options) => captured = options);

    await dio.get<dynamic>(
      'https://api.example.com/api/v1/profile',
      options: Options(headers: {apiRequestIdHeader: 'explicit-id'}),
    );

    expect(captured!.headers[apiRequestIdHeader], 'explicit-id');
  });
}
