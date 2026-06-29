import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_preparation_level_diagnoser.dart';
import 'package:scho_navi/data/http/http_preparation_level_diagnoser.dart';
import 'package:scho_navi/data/mock/fake_backend.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

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
  test('HTTP 调用 fake 后端返回水平诊断', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://fake.local'));
    dio.httpClientAdapter = FakeBackendAdapter()
      ..registerPreparationDiagnoseHandler();
    final d = HttpPreparationLevelDiagnoser(dio);

    final r = await d.diagnose(_req());

    expect(r, isA<Success<LevelDiagnosisSuggestion>>());
    final data = (r as Success<LevelDiagnosisSuggestion>).data;
    expect(data.level, ExperienceLevel.intermediate);
    expect(data.rationale, '根据你的参赛经历和领域熟悉度，你已具备进阶基础。');
    expect(data.suggestion, '建议按进阶档排期；时间充裕时可增加老手档训练。');
  });

  test('默认 handler map 已注册 diagnose 端点（无需手动 register）', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://fake.local'));
    dio.httpClientAdapter = FakeBackendAdapter();
    final d = HttpPreparationLevelDiagnoser(dio);

    final r = await d.diagnose(_req());

    expect(r, isA<Success<LevelDiagnosisSuggestion>>());
    expect(
      (r as Success<LevelDiagnosisSuggestion>).data.level,
      ExperienceLevel.intermediate,
    );
  });
}
