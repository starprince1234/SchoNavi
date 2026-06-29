import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_preparation_level_diagnoser.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

class _StubLlm implements LlmClient {
  _StubLlm(this._out);

  final Result<String> _out;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async => _out;

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => throw UnimplementedError();
}

LevelDiagnosisRequest _req() => LevelDiagnosisRequest(
  competition: CompetitionSnapshot(
    id: 'comp_icpc',
    name: 'ACM-ICPC',
    category: '计算机类',
    rulesSummary: CompetitionRulesSummary(
      signupTime: '',
      contestTime: '',
      teamSize: '',
      format: '',
      organizer: '',
      officialUrl: null,
    ),
  ),
  answers: const [
    DiagnosisAnswer(questionKey: 'prior_experience', answer: '拿过校级以上奖'),
    DiagnosisAnswer(questionKey: 'domain_familiarity', answer: '熟悉'),
  ],
  profile: null,
);

void main() {
  test('解析合法 JSON 返回 level/rationale/suggestion', () async {
    final llm = _StubLlm(
      Success(
        jsonEncode({
          'level': 'intermediate',
          'rationale': '根据你的参赛经历和算法熟悉度，你已具备进阶基础。',
          'suggestion': '建议按进阶档排期；时间充裕时可增加老手档训练。',
        }),
      ),
    );
    final d = AiPreparationLevelDiagnoser(llm);
    final r = await d.diagnose(_req());
    expect(r, isA<Success<LevelDiagnosisSuggestion>>());
    final data = (r as Success<LevelDiagnosisSuggestion>).data;
    expect(data.level, ExperienceLevel.intermediate);
    expect(data.rationale, '根据你的参赛经历和算法熟悉度，你已具备进阶基础。');
    expect(data.suggestion, '建议按进阶档排期；时间充裕时可增加老手档训练。');
  });

  test('非法 level 丢弃为 Failure', () async {
    final llm = _StubLlm(
      Success(
        jsonEncode({
          'level': 'expert',
          'rationale': '...',
          'suggestion': '...',
        }),
      ),
    );
    final r = await AiPreparationLevelDiagnoser(llm).diagnose(_req());
    expect(r, isA<Failure<LevelDiagnosisSuggestion>>());
    expect((r as Failure).error, isA<ServerException>());
  });

  test('畸形 JSON 返回 Failure', () async {
    final llm = _StubLlm(const Success('not json'));
    final r = await AiPreparationLevelDiagnoser(llm).diagnose(_req());
    expect(r, isA<Failure<LevelDiagnosisSuggestion>>());
  });

  test('Llm 未配置返回 Failure', () async {
    final llm = _StubLlm(const Failure(MissingLlmConfigurationException()));
    final r = await AiPreparationLevelDiagnoser(llm).diagnose(_req());
    expect(r, isA<Failure<LevelDiagnosisSuggestion>>());
    expect((r as Failure).error, isA<MissingLlmConfigurationException>());
  });

  test('level 缺失返回 Failure', () async {
    final llm = _StubLlm(
      Success(jsonEncode({'rationale': '...', 'suggestion': '...'})),
    );
    final r = await AiPreparationLevelDiagnoser(llm).diagnose(_req());
    expect(r, isA<Failure<LevelDiagnosisSuggestion>>());
  });
}
