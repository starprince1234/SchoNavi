import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/deepseek_llm_client.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';

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

ResponseBody _sseBody(List<String> events, {int code = 200}) {
  Stream<Uint8List> chunks() async* {
    for (final event in events) {
      yield Uint8List.fromList(utf8.encode(event));
    }
  }

  return ResponseBody(
    chunks(),
    code,
    headers: {
      Headers.contentTypeHeader: ['text/event-stream'],
    },
  );
}

String _delta(String content) {
  return 'data: ${jsonEncode({
    'choices': [
      {
        'delta': {'content': content},
      },
    ],
  })}\n\n';
}

void main() {
  test('parses SSE deltas and sends stream:true', () async {
    RequestOptions? captured;
    final adapter = _FakeAdapter((options) async {
      captured = options;
      return _sseBody([_delta('你'), _delta('好'), 'data: [DONE]\n\n']);
    });

    final deltas = await _client(
      adapter,
    ).stream(messages: const [LlmMessage('user', 'hi')]).toList();

    expect(deltas, ['你', '好']);
    final data = captured!.data as Map;
    expect(data['model'], 'deepseek-chat');
    expect(data['stream'], true);
  });

  test('ignores empty delta and non data lines', () async {
    final adapter = _FakeAdapter(
      (_) async => _sseBody([
        ': keep-alive\n\n',
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'role': 'assistant'},
            },
          ],
        })}\n\n',
        _delta('答案'),
        'data: [DONE]\n\n',
      ]),
    );

    final deltas = await _client(
      adapter,
    ).stream(messages: const [LlmMessage('user', 'hi')]).toList();

    expect(deltas, ['答案']);
  });

  test('HTTP 500 maps to ServerException', () async {
    final adapter = _FakeAdapter(
      (_) async => ResponseBody.fromString(
        '{"error":"err"}',
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );

    await expectLater(
      _client(adapter).stream(messages: const [LlmMessage('user', 'hi')]),
      emitsError(isA<ServerException>()),
    );
  });

  test('connection error maps to NetworkException', () async {
    final adapter = _FakeAdapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );

    await expectLater(
      _client(adapter).stream(messages: const [LlmMessage('user', 'hi')]),
      emitsError(isA<NetworkException>()),
    );
  });
}
