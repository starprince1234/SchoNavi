import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/http/http_feedback_repository.dart';
import 'package:scho_navi/domain/entities/feedback.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
}

Dio _dio(Future<ResponseBody> Function(RequestOptions) handler) =>
    Dio(BaseOptions(baseUrl: 'https://api.example.com'))
      ..httpClientAdapter = _FakeAdapter(handler);

ResponseBody _json(String text) => ResponseBody.fromString(
  text,
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Feedback _feedback() => Feedback(
  id: 'id1',
  type: FeedbackType.recommendation,
  content: '推荐不准',
  contact: null,
  context: FeedbackContext(
    professorId: 'P001',
    appVersion: '1.2.0',
    dataSourceMode: 'http',
  ),
  createdAt: DateTime.utc(2026, 6, 30),
);

void main() {
  test('posts to /api/v1/feedback and returns Success on code 0', () async {
    RequestOptions? captured;
    final repo = HttpFeedbackRepository(
      _dio((options) async {
        captured = options;
        return _json(
          jsonEncode({
            'code': 0,
            'message': 'ok',
            'data': {
              'id': 'id1',
              'status': 'received',
              'received_at': '2026-06-30T12:00:01Z',
            },
          }),
        );
      }),
    );

    final result = await repo.submit(_feedback());

    expect(captured!.path, '/api/v1/feedback');
    expect(captured!.method, 'POST');
    final body = captured!.data as Map<String, dynamic>;
    expect(body['type'], 'recommendation');
    expect((body['context'] as Map)['professor_id'], 'P001');
    expect(result, isA<Success<void>>());
  });

  test('non-zero envelope maps to Failure', () async {
    final repo = HttpFeedbackRepository(
      _dio(
        (_) async =>
            _json(jsonEncode({'code': 1001, 'message': '内容不合法', 'data': null})),
      ),
    );

    final result = await repo.submit(_feedback());

    expect(result, isA<Failure<void>>());
    expect((result as Failure<void>).error.message, '内容不合法');
  });

  test('dio timeout maps to TimeoutException failure', () async {
    final repo = HttpFeedbackRepository(
      _dio(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      ),
    );

    final result = await repo.submit(_feedback());

    expect((result as Failure<void>).error, isA<TimeoutException>());
  });
}
