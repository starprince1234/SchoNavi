import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/deepseek_llm_client.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';

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
  ) {
    return handler(options);
  }
}

DeepSeekLlmClient _client(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return DeepSeekLlmClient(
    dio: dio,
    apiKey: 'sk-test',
    baseUrl: 'https://api.deepseek.com',
    model: 'deepseek-chat',
  );
}

ResponseBody _json(String body, int code) {
  return ResponseBody.fromString(
    body,
    code,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  test('success extracts content and sends model/messages/json mode', () async {
    RequestOptions? captured;
    final adapter = _FakeAdapter((options) async {
      captured = options;
      return _json(
        jsonEncode({
          'choices': [
            {
              'message': {'content': '生成结果'},
            },
          ],
        }),
        200,
      );
    });

    final res = await _client(
      adapter,
    ).complete(messages: const [LlmMessage('user', 'hi')], jsonMode: true);

    expect((res as Success<String>).data, '生成结果');
    final data = captured!.data as Map;
    expect(data['model'], 'deepseek-chat');
    expect(data['messages'], [
      {'role': 'user', 'content': 'hi'},
    ]);
    expect(data['response_format'], {'type': 'json_object'});
    expect(data['stream'], false);
  });

  test('500 maps to ServerException', () async {
    final adapter = _FakeAdapter((_) async => _json('{"error":"err"}', 500));

    final res = await _client(
      adapter,
    ).complete(messages: const [LlmMessage('user', 'hi')]);

    expect((res as Failure<String>).error, isA<ServerException>());
  });

  test('receive timeout maps to TimeoutException', () async {
    final adapter = _FakeAdapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    });

    final res = await _client(
      adapter,
    ).complete(messages: const [LlmMessage('user', 'hi')]);

    expect((res as Failure<String>).error, isA<TimeoutException>());
  });

  test('connection error maps to NetworkException', () async {
    final adapter = _FakeAdapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });

    final res = await _client(
      adapter,
    ).complete(messages: const [LlmMessage('user', 'hi')]);

    expect((res as Failure<String>).error, isA<NetworkException>());
  });

  test('empty choices maps to ServerException', () async {
    final adapter = _FakeAdapter(
      (_) async => _json(jsonEncode({'choices': []}), 200),
    );

    final res = await _client(
      adapter,
    ).complete(messages: const [LlmMessage('user', 'hi')]);

    expect((res as Failure<String>).error, isA<ServerException>());
  });
}
