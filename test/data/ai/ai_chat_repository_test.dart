import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/core/storage/local_store.dart';
import 'package:scho_navi/data/ai/ai_chat_repository.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';

class _RecordingLlm implements LlmClient {
  _RecordingLlm(this.reply);

  String reply;
  final List<List<LlmMessage>> calls = [];

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    calls.add(messages);
    return Success(reply);
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => throw UnimplementedError();
}

class _FailLlm implements LlmClient {
  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    return const Failure(ServerException());
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => throw UnimplementedError();
}

class _QueueLlm implements LlmClient {
  _QueueLlm(this.queue);

  final List<Stream<String>> queue;
  int _call = 0;
  final List<List<LlmMessage>> calls = [];

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async => throw UnimplementedError();

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) {
    calls.add(messages);
    return queue[_call++];
  }
}

void main() {
  test('answer/sessionId pass through and no embedded cards', () async {
    final repo = AiChatRepository(llm: _RecordingLlm('你好'), db: MockDb(), historyStore: _historyStore());

    final res = await repo.sendMessage(sessionId: 's1', message: '在吗');

    final data = (res as Success<ChatResult>).data;
    expect(data.answer, '你好');
    expect(data.sessionId, 's1');
    expect(data.relatedRecommendations, isEmpty);
  });

  test('second call includes previous history', () async {
    final llm = _RecordingLlm('A');
    final repo = AiChatRepository(llm: llm, db: MockDb(), historyStore: _historyStore());

    await repo.sendMessage(sessionId: 's1', message: '问题一');
    llm.reply = 'B';
    await repo.sendMessage(sessionId: 's1', message: '问题二');

    final contents = llm.calls.last.map((m) => m.content).toList();
    expect(contents, containsAll(['问题一', 'A', '问题二']));
  });

  test('professorId injects professor context into system prompt', () async {
    final llm = _RecordingLlm('ok');
    final repo = AiChatRepository(llm: llm, db: MockDb(), historyStore: _historyStore());

    await repo.sendMessage(
      sessionId: 's1',
      message: '为什么推荐他',
      professorId: 'p_001',
    );

    final system = llm.calls.last.first;
    expect(system.role, 'system');
    expect(system.content, contains('张三'));
  });

  test('regenerate does not duplicate repeated last user message', () async {
    final llm = _RecordingLlm('A1');
    final repo = AiChatRepository(llm: llm, db: MockDb(), historyStore: _historyStore());

    await repo.sendMessage(sessionId: 's1', message: '同一个问题');
    llm.reply = 'A2';
    await repo.sendMessage(sessionId: 's1', message: '同一个问题');

    final userCount = llm.calls.last
        .where((m) => m.role == 'user' && m.content == '同一个问题')
        .length;
    expect(userCount, 1);
  });

  test('LLM failure passes through', () async {
    final repo = AiChatRepository(llm: _FailLlm(), db: MockDb(), historyStore: _historyStore());

    final res = await repo.sendMessage(sessionId: 's1', message: 'x');

    expect((res as Failure).error, isA<ServerException>());
  });

  group('streamReply', () {
    test('passes through deltas', () async {
      final repo = AiChatRepository(
        llm: _QueueLlm([
          Stream.fromIterable(const ['你', '好']),
        ]),
        db: MockDb(),
        historyStore: _historyStore(),
      );

      final out = await repo
          .streamReply(sessionId: 's1', message: '在吗')
          .toList();

      expect(out, ['你', '好']);
    });

    test('adds completed answer to history for next turn', () async {
      final llm = _QueueLlm([
        Stream.fromIterable(const ['你', '好']),
        Stream.fromIterable(const ['再见']),
      ]);
      final repo = AiChatRepository(llm: llm, db: MockDb(), historyStore: _historyStore());

      await repo.streamReply(sessionId: 's1', message: '问题一').toList();
      await repo.streamReply(sessionId: 's1', message: '问题二').toList();

      final contents = llm.calls.last.map((m) => m.content).toList();
      expect(contents, containsAll(['问题一', '你好', '问题二']));
    });

    test('professorId injects professor context into system prompt', () async {
      final llm = _QueueLlm([
        Stream.fromIterable(const ['ok']),
      ]);
      final repo = AiChatRepository(llm: llm, db: MockDb(), historyStore: _historyStore());

      await repo
          .streamReply(sessionId: 's1', message: '为什么', professorId: 'p_001')
          .toList();

      final system = llm.calls.last.first;
      expect(system.role, 'system');
      expect(system.content, contains('张三'));
    });

    test(
      'stream error passes through and partial answer is discarded',
      () async {
        final llm = _QueueLlm([
          Stream<String>.error(const ServerException()),
          Stream.fromIterable(const ['好的']),
        ]);
        final repo = AiChatRepository(llm: llm, db: MockDb(), historyStore: _historyStore());

        await expectLater(
          repo.streamReply(sessionId: 's1', message: '问题一'),
          emitsError(isA<ServerException>()),
        );
        await repo.streamReply(sessionId: 's1', message: '问题二').toList();

        expect(llm.calls.last.where((m) => m.role == 'assistant'), isEmpty);
      },
    );

    test('cancel keeps visible partial answer in history', () async {
      final controller = StreamController<String>();
      addTearDown(controller.close);
      final llm = _QueueLlm([
        controller.stream,
        Stream.fromIterable(const ['继续']),
      ]);
      final repo = AiChatRepository(llm: llm, db: MockDb(), historyStore: _historyStore());

      final got = <String>[];
      final sub = repo
          .streamReply(sessionId: 's1', message: '问题一')
          .listen(got.add);
      controller.add('部分');
      controller.add('答案');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      await repo.streamReply(sessionId: 's1', message: '问题二').toList();
      final contents = llm.calls.last.map((m) => m.content).toList();
      expect(got, ['部分', '答案']);
      expect(contents, containsAllInOrder(['问题一', '部分答案', '问题二']));
    });
  });

  group('seedRecommendationTurn', () {
    RecommendationResult resultWithRec() => RecommendationResult(
      sessionId: 's1',
      queryUnderstanding: const QueryUnderstanding(
        researchInterests: ['计算机视觉'],
        preferredLocations: ['北京'],
        preferredUniversities: [],
        degreeStage: null,
        uncertainties: [],
      ),
      recommendations: const [
        Recommendation(
          professorId: 'p_001',
          name: '张三',
          university: '清华大学',
          college: '计算机学院',
          title: '教授',
          researchFields: ['计算机视觉'],
          matchLevel: MatchLevel.high,
          reason: '方向高度契合',
          limitations: [],
        ),
      ],
      followUpQuestions: const [],
    );

    test('注入后后续 streamReply 的 LLM 调用能看到推荐摘要', () async {
      final llm = _QueueLlm([
        Stream.fromIterable(const ['好的']),
      ]);
      final repo = AiChatRepository(llm: llm, db: MockDb(), historyStore: _historyStore());

      await repo.seedRecommendationTurn(
        sessionId: 's1',
        userPrompt: '想做计算机视觉',
        result: resultWithRec(),
      );
      await repo.streamReply(sessionId: 's1', message: '第一位的研究方向').toList();

      final messages = llm.calls.last;
      final contents = messages.map((m) => m.content).toList();
      expect(contents, anyElement(contains('张三')));
      expect(contents, anyElement(contains('计算机视觉')));
      expect(
        messages
            .where((message) => message.role != 'system')
            .map((message) => '${message.role}:${message.content}')
            .toList(),
        containsAllInOrder([
          'user:想做计算机视觉',
          contains('assistant:【上一轮已为用户推荐以下导师】'),
          'user:第一位的研究方向',
        ]),
      );
    });

    test('未注入推荐轮时上下文不含推荐摘要（回归保护）', () async {
      final llm = _QueueLlm([
        Stream.fromIterable(const ['好的']),
      ]);
      final repo = AiChatRepository(llm: llm, db: MockDb(), historyStore: _historyStore());

      await repo.streamReply(sessionId: 's1', message: '在吗').toList();

      final assistantContents = llm.calls.last
          .where((m) => m.role == 'assistant')
          .map((m) => m.content)
          .toList();
      expect(assistantContents, isEmpty);
    });
  });
}

class _TestStore implements LocalStore {
  final Map<String, dynamic> _m = {};
  @override
  String? getString(String key) => _m[key] as String?;
  @override
  Future<void> setString(String key, String value) async => _m[key] = value;
  @override
  bool? getBool(String key) => _m[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => _m[key] = value;
  @override
  Map<String, dynamic>? getJson(String key) => _m[key] as Map<String, dynamic>?;
  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async =>
      _m[key] = value;
  @override
  List<dynamic>? getJsonList(String key) => _m[key] as List<dynamic>?;
  @override
  Future<void> setJsonList(String key, List<dynamic> value) async =>
      _m[key] = value;
  @override
  bool containsKey(String key) => _m.containsKey(key);
  @override
  Future<void> remove(String key) async => _m.remove(key);
  @override
  Future<void> clear() async => _m.clear();
}

LocalChatHistoryStore _historyStore() => LocalChatHistoryStore(_TestStore());
