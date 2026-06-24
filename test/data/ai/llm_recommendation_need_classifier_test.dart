import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/llm_recommendation_need_classifier.dart';
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
  group('LlmRecommendationNeedClassifier', () {
    test('need=true 时返回 true', () async {
      final c = LlmRecommendationNeedClassifier(
        const _FakeLlm(Success('{"need":true}')),
      );
      expect(
        await c.needRecommendations('只看上海的', lastResult: _resultWith()),
        isTrue,
      );
    });

    test('need=false 时返回 false', () async {
      final c = LlmRecommendationNeedClassifier(
        const _FakeLlm(Success('{"need":false}')),
      );
      expect(
        await c.needRecommendations('为什么推荐他', lastResult: _resultWith()),
        isFalse,
      );
    });

    test('LLM 失败时降级返回 false（不阻断对话，宁可少产卡）', () async {
      final c = LlmRecommendationNeedClassifier(
        const _FakeLlm(Failure(NetworkException())),
      );
      expect(
        await c.needRecommendations('随便问问', lastResult: _resultWith()),
        isFalse,
      );
    });

    test('畸形输出降级返回 false', () async {
      final c = LlmRecommendationNeedClassifier(
        const _FakeLlm(Success('{"intent":"other"}')),
      );
      expect(
        await c.needRecommendations('x', lastResult: _resultWith()),
        isFalse,
      );
    });

    test('无上一轮结果时仍可判定（首轮追问场景的兜底）', () async {
      final c = LlmRecommendationNeedClassifier(
        const _FakeLlm(Success('{"need":true}')),
      );
      expect(await c.needRecommendations('再推荐几位', lastResult: null), isTrue);
    });

    test('prompt 含上一轮推荐摘要供 LLM 判断', () async {
      final calls = <List<LlmMessage>>[];
      final llm = _FakeLlm(const Success('{"need":false}'));
      // 包装一层记录调用。
      final recording = _RecordingLlm(llm, calls);
      final c = LlmRecommendationNeedClassifier(recording);

      await c.needRecommendations(
        '第一位的研究方向',
        lastResult: _resultWith(recs: [_rec]),
      );

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
