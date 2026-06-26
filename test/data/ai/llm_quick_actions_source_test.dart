import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/llm_quick_actions_source.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';

class _FakeLlm implements LlmClient {
  const _FakeLlm(this._result);
  final Result<String> _result;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async => _result;

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => throw UnimplementedError();
}

class _RecordingLlm implements LlmClient {
  _RecordingLlm(this._delegate, this.calls);
  final LlmClient _delegate;
  final List<List<LlmMessage>> calls;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) {
    calls.add(messages);
    return _delegate.complete(
      messages: messages,
      jsonMode: jsonMode,
      temperature: temperature,
    );
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => _delegate.stream(messages: messages, temperature: temperature);
}

RecommendationResult _resultWith({List<Recommendation>? recs}) {
  return RecommendationResult(
    sessionId: 's_1',
    queryUnderstanding: const QueryUnderstanding(
      researchInterests: ['计算机视觉'],
      preferredLocations: ['北京'],
      preferredUniversities: [],
      degreeStage: null,
      uncertainties: [],
    ),
    recommendations: recs ?? const [],
    followUpQuestions: const [],
  );
}

const _rec = Recommendation(
  professorId: 'p_001',
  name: '张三',
  university: '清华大学',
  college: '计算机学院',
  title: '教授',
  researchFields: ['计算机视觉'],
  matchLevel: MatchLevel.high,
  reason: '方向契合',
  limitations: [],
);

void main() {
  group('LlmQuickActionsSource', () {
    test('解析 quick_actions 数组返回 Success', () async {
      final src = LlmQuickActionsSource(
        const _FakeLlm(Success('{"quick_actions":["换一批","偏应用"]}')),
      );
      final result = await src.fetch(followUp: '换一批', lastResult: _resultWith());

      expect(result, isA<Success<List<String>>>());
      expect((result as Success<List<String>>).data, ['换一批', '偏应用']);
    });

    test('畸形 JSON 降级为 Success 空列表（非 Failure）', () async {
      final src = LlmQuickActionsSource(
        const _FakeLlm(Success('{"intent":"other"}')),
      );
      final result = await src.fetch(followUp: 'x', lastResult: _resultWith());

      expect(result, isA<Success<List<String>>>());
      expect((result as Success<List<String>>).data, isEmpty);
    });

    test('quick_actions 非 List 降级为 Success 空列表', () async {
      final src = LlmQuickActionsSource(
        const _FakeLlm(Success('{"quick_actions":"not-a-list"}')),
      );
      final result = await src.fetch(followUp: 'x', lastResult: _resultWith());

      expect(result, isA<Success<List<String>>>());
      expect((result as Success<List<String>>).data, isEmpty);
    });

    test('LLM 失败返回 Failure（触发硬编码兜底）', () async {
      final src = LlmQuickActionsSource(
        const _FakeLlm(Failure(NetworkException())),
      );
      final result = await src.fetch(followUp: 'x', lastResult: _resultWith());

      expect(result, isA<Failure<List<String>>>());
      expect(
        (result as Failure<List<String>>).error,
        isA<NetworkException>(),
      );
    });

    test('无上一轮结果时仍可生成', () async {
      final src = LlmQuickActionsSource(
        const _FakeLlm(Success('{"quick_actions":["偏应用"]}')),
      );
      final result = await src.fetch(followUp: '继续', lastResult: null);

      expect(result, isA<Success<List<String>>>());
      expect((result as Success<List<String>>).data, ['偏应用']);
    });

    test('prompt 含上一轮推荐摘要', () async {
      final calls = <List<LlmMessage>>[];
      final llm = _RecordingLlm(
        const _FakeLlm(Success('{"quick_actions":["偏应用"]}')),
        calls,
      );
      final src = LlmQuickActionsSource(llm);

      await src.fetch(followUp: '第一位的研究方向', lastResult: _resultWith(recs: [_rec]));

      expect(calls, hasLength(1));
      final userContent = calls.single
          .where((m) => m.role == 'user')
          .map((m) => m.content)
          .join();
      expect(userContent, contains('张三'));
      expect(userContent, contains('计算机视觉'));
    });
  });
}
