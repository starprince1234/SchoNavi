import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/http/http_chat_repository.dart';
import 'package:scho_navi/data/http/http_history_repository.dart';
import 'package:scho_navi/data/http/http_professor_repository.dart';
import 'package:scho_navi/data/http/http_recommendation_repository.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/entities/search_history_item.dart';

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

void main() {
  test('AppConfig resolves HTTP mode from API_BASE_URL', () {
    final cfg = AppConfig.resolve(
      apiKey: 'sk-test',
      apiBaseUrl: 'https://api.example.com/',
    );

    expect(cfg.dataSource, DataSource.http);
    expect(cfg.api.baseUrl, 'https://api.example.com');
    expect(cfg.llm.apiKey, 'sk-test');
  });

  test('HttpRecommendationRepository posts contract request and decodes envelope', () async {
    RequestOptions? captured;
    final repo = HttpRecommendationRepository(
      _dio((options) async {
        captured = options;
        return _jsonFixture('mentor_recommendation_success.json');
      }),
    );

    final result = await repo.getRecommendations(prompt: '医学影像');

    expect(captured!.path, '/api/v1/recommendations/mentors');
    expect(captured!.method, 'POST');
    expect((captured!.data as Map)['prompt'], '医学影像');
    final data = (result as Success).data;
    expect(data.sessionId, 's_123');
    expect(data.recommendations.single.professorId, 'p_001');
  });

  test('HttpProfessorRepository decodes professor envelope', () async {
    final repo = HttpProfessorRepository(
      _dio((_) async => _jsonFixture('professor_success.json')),
    );

    final result = await repo.getProfessor('p_001');

    final professor = (result as Success).data;
    expect(professor.id, 'p_001');
    expect(professor.dataQualityScore, 0.87);
  });

  test('non-zero envelope maps to Failure with backend message', () async {
    final repo = HttpRecommendationRepository(
      _dio((_) async => _jsonFixture('envelope_error.json')),
    );

    final result = await repo.getRecommendations(prompt: ' ');

    expect(result, isA<Failure>());
    expect((result as Failure).error.message, '输入内容不合法');
  });

  test('Dio timeout maps to TimeoutException', () async {
    final repo = HttpProfessorRepository(
      _dio((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      }),
    );

    final result = await repo.getProfessor('p_001');

    expect((result as Failure).error, isA<TimeoutException>());
  });

  test('malformed success data maps to ServerException failure', () async {
    final repo = HttpProfessorRepository(
      _dio(
        (_) async => _jsonString(
          jsonEncode({'code': 0, 'message': 'ok', 'data': {'bad': true}}),
        ),
      ),
    );

    final result = await repo.getProfessor('p_001');

    expect((result as Failure).error, isA<ServerException>());
  });

  test('HttpChatRepository parses contract SSE deltas', () async {
    RequestOptions? captured;
    final repo = HttpChatRepository(
      _dio((options) async {
        captured = options;
        return _sseBody([
          'event: delta\ndata: {"text":"你"}\n\n',
          'event: delta\ndata: {"text":"好"}\n\n',
          'event: done\ndata: {"session_id":"s_123"}\n\n',
        ]);
      }),
    );

    final deltas = await repo
        .streamReply(sessionId: 's_123', message: 'hi', professorId: 'p_001')
        .toList();

    expect(captured!.path, '/api/v1/chat/stream');
    expect(captured!.queryParameters['professor_id'], 'p_001');
    expect(deltas, ['你', '好']);
  });

  test('HttpHistoryRepository lists search history from envelope', () async {
    RequestOptions? captured;
    final repo = HttpHistoryRepository(
      _dio((options) async {
        captured = options;
        await Future<void>.delayed(const Duration(milliseconds: 1));
        return _jsonString(
          jsonEncode({
            'code': 0,
            'message': 'ok',
            'data': [_historyJson('s_1')],
          }),
        );
      }),
    );

    final emitted = await repo.watch().skip(1).first;

    expect(captured!.path, '/api/v1/history');
    expect(captured!.method, 'GET');
    expect(emitted.single.sessionId, 's_1');
    expect(emitted.single.type, SearchHistoryType.mentor);
  });

  test('HttpHistoryRepository posts generated search history item', () async {
    RequestOptions? captured;
    final repo = HttpHistoryRepository(
      _dio((options) async {
        captured = options;
        return _jsonString(
          jsonEncode({
            'code': 0,
            'message': 'ok',
            'data': _historyJson('s_123'),
          }),
        );
      }),
      now: () => DateTime.utc(2026, 6, 15, 10),
    );

    await repo.addFromResult(prompt: '医学影像 上海', result: _recommendationResult());

    expect(captured!.path, '/api/v1/history');
    expect(captured!.method, 'POST');
    expect(captured!.data, {
      'type': 'mentor',
      'session_id': 's_123',
      'prompt': '医学影像 上海',
      'created_at': '2026-06-15T10:00:00.000Z',
      'summary': '方向：医学影像 / 地区：上海',
      'research_interests': ['医学影像'],
      'preferred_locations': ['上海'],
      'recommendation_count': 1,
    });
  });

  test('HttpHistoryRepository deletes one item and clears all history', () async {
    final captured = <RequestOptions>[];
    final repo = HttpHistoryRepository(
      _dio((options) async {
        captured.add(options);
        return _jsonString(
          jsonEncode({'code': 0, 'message': 'ok', 'data': {'removed': true}}),
        );
      }),
    );

    await repo.remove('s_123');
    await repo.clear();

    expect(captured[0].path, '/api/v1/history/s_123');
    expect(captured[0].method, 'DELETE');
    expect(captured[1].path, '/api/v1/history');
    expect(captured[1].method, 'DELETE');
  });
}

Dio _dio(Future<ResponseBody> Function(RequestOptions options) handler) {
  return Dio(BaseOptions(baseUrl: 'https://api.example.com'))
    ..httpClientAdapter = _FakeAdapter(handler);
}

ResponseBody _jsonFixture(String name) {
  final text = File('test/fixtures/api/$name').readAsStringSync();
  return _jsonString(text);
}

ResponseBody _jsonString(String text) {
  return ResponseBody.fromString(
    text,
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

ResponseBody _sseBody(List<String> events) {
  Stream<Uint8List> chunks() async* {
    for (final event in events) {
      yield Uint8List.fromList(utf8.encode(event));
    }
  }

  return ResponseBody(
    chunks(),
    200,
    headers: {
      Headers.contentTypeHeader: ['text/event-stream'],
    },
  );
}

Map<String, dynamic> _historyJson(String sessionId) => <String, dynamic>{
  'type': 'mentor',
  'session_id': sessionId,
  'prompt': '医学影像 上海',
  'created_at': '2026-06-15T10:00:00.000Z',
  'summary': '方向：医学影像 / 地区：上海',
  'research_interests': ['医学影像'],
  'preferred_locations': ['上海'],
  'recommendation_count': 1,
};

RecommendationResult _recommendationResult() => const RecommendationResult(
  sessionId: 's_123',
  queryUnderstanding: QueryUnderstanding(
    researchInterests: ['医学影像'],
    preferredLocations: ['上海'],
    preferredUniversities: [],
    uncertainties: [],
  ),
  recommendations: [
    Recommendation(
      professorId: 'p_001',
      name: '张三',
      university: '上海交通大学',
      college: '电子信息与电气工程学院',
      title: '教授',
      researchFields: ['医学影像'],
      matchLevel: MatchLevel.high,
      reason: '方向匹配。',
      limitations: ['以官网为准'],
    ),
  ],
  followUpQuestions: [],
);
