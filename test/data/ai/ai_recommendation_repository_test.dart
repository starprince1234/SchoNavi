import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_recommendation_repository.dart';
import 'package:scho_navi/data/ai/professor_candidate_source.dart';
import 'package:scho_navi/domain/entities/professor.dart';

class _FakeLlm implements LlmClient {
  _FakeLlm(this._result);

  final Result<String> _result;
  bool? lastJsonMode;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    lastJsonMode = jsonMode;
    return _result;
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => throw UnimplementedError();
}

class _FixedCandidates implements ProfessorCandidateSource {
  const _FixedCandidates(this.pool);

  final List<Professor> pool;

  @override
  List<Professor> candidatesFor(String prompt) => pool;
}

const _p1 = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像', '计算机视觉'],
  bio: '研究医学影像。',
  homepageUrl: 'https://example.edu.cn/zhangsan',
);

void main() {
  const candidates = _FixedCandidates([_p1]);

  test('parses result and fills professor facts from candidates', () async {
    final content = jsonEncode({
      'queryUnderstanding': {
        'researchInterests': ['医学影像'],
        'preferredLocations': ['上海'],
        'preferredUniversities': <String>[],
        'degreeStage': '硕士',
        'uncertainties': <String>[],
      },
      'recommendations': [
        {
          'professorId': 'p_001',
          'matchLevel': 'high',
          'reason': '方向高度相关',
          'limitations': ['以学校官网为准'],
        },
      ],
      'followUpQuestions': ['偏理论还是应用？'],
    });
    final repo = AiRecommendationRepository(
      llm: _FakeLlm(Success(content)),
      candidates: candidates,
    );

    final res = await repo.getRecommendations(prompt: '医学影像 上海 硕士');

    final data = (res as Success).data;
    expect(data.recommendations, hasLength(1));
    final rec = data.recommendations.single;
    expect(rec.professorId, 'p_001');
    expect(rec.name, '张三');
    expect(rec.university, '上海交通大学');
    expect(rec.reason, '方向高度相关');
    expect(rec.matchScore, isNull);
    expect(data.queryUnderstanding.degreeStage, '硕士');
    expect(data.followUpQuestions, contains('偏理论还是应用？'));
  });

  test('uses JSON mode', () async {
    final fake = _FakeLlm(const Success('{"recommendations":[]}'));
    final repo = AiRecommendationRepository(llm: fake, candidates: candidates);

    await repo.getRecommendations(prompt: 'x');

    expect(fake.lastJsonMode, isTrue);
  });

  test('grounding drops professorId outside candidate pool', () async {
    final content = jsonEncode({
      'recommendations': [
        {
          'professorId': 'p_999',
          'matchLevel': 'high',
          'reason': '伪造',
          'limitations': <String>[],
        },
        {
          'professorId': 'p_001',
          'matchLevel': 'medium',
          'reason': '真实候选',
          'limitations': <String>[],
        },
      ],
    });
    final repo = AiRecommendationRepository(
      llm: _FakeLlm(Success(content)),
      candidates: candidates,
    );

    final data = (await repo.getRecommendations(prompt: 'x') as Success).data;

    expect(data.recommendations.map((r) => r.professorId), ['p_001']);
  });

  test('empty recommendations is successful', () async {
    final repo = AiRecommendationRepository(
      llm: _FakeLlm(const Success('{"recommendations":[]}')),
      candidates: candidates,
    );

    final res = await repo.getRecommendations(prompt: 'x');

    expect((res as Success).data.recommendations, isEmpty);
  });

  test('malformed JSON returns ServerException failure', () async {
    final repo = AiRecommendationRepository(
      llm: _FakeLlm(const Success('not json')),
      candidates: candidates,
    );

    final res = await repo.getRecommendations(prompt: 'x');

    expect((res as Failure).error, isA<ServerException>());
  });

  test('LLM failure passes through', () async {
    final repo = AiRecommendationRepository(
      llm: _FakeLlm(const Failure(NetworkException())),
      candidates: candidates,
    );

    final res = await repo.getRecommendations(prompt: 'x');

    expect((res as Failure).error, isA<NetworkException>());
  });
}
