import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_preparation_personalizer.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

/// Stub LlmClient：固定返回预设 [Result]；不实现 stream（本任务用不到）。
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

PreparationPersonalizationRequest _req() => PreparationPersonalizationRequest(
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
      targetDate: DateTime(2026, 9, 1),
      weeklyCommitment: WeeklyCommitment.hours6to10,
      experienceLevel: ExperienceLevel.beginner,
      phaseKeys: const [
        'team_formation',
        'topic_selection',
        'proposal_writing',
        'submission_polish',
        'defense_prep',
      ],
      profile: null,
    );

void main() {
  test('解析合法 JSON', () async {
    final llm = _StubLlm(const Success(
      '{"phases":[{"key":"proposal_writing","optionalTasks":'
      '[{"templateKey":"ai_algo","title":"强化训练","estimatedHours":10}],'
      '"personalizedAdvice":"多刷真题"}],"globalAdvice":"整体偏算法"}',
    ));
    final p = AiPreparationPersonalizer(llm);
    final r = await p.personalize(req: _req());
    expect(r, isA<Success<PreparationPersonalizationResult>>());
    final data = (r as Success<PreparationPersonalizationResult>).data;
    expect(data.phases.length, 1);
    expect(data.phases[0].key, 'proposal_writing');
    expect(data.phases[0].optionalTasks[0].title, '强化训练');
    expect(data.phases[0].optionalTasks[0].templateKey, 'ai_algo');
    expect(data.phases[0].optionalTasks[0].estimatedHours, 10);
    expect(data.phases[0].personalizedAdvice, '多刷真题');
    expect(data.globalAdvice, '整体偏算法');
  });

  test('未知 phaseKey 丢弃', () async {
    final llm = _StubLlm(const Success(
      '{"phases":[{"key":"unknown_phase","optionalTasks":[]}]}',
    ));
    final r = await AiPreparationPersonalizer(llm).personalize(req: _req());
    final data = (r as Success).data as PreparationPersonalizationResult;
    expect(data.phases, isEmpty);
  });

  test('重复 templateKey 丢弃 + 每阶段 >3 截断', () async {
    final llm = _StubLlm(const Success(
      '{"phases":[{"key":"proposal_writing","optionalTasks":['
      '{"templateKey":"dup","title":"A","estimatedHours":1},'
      '{"templateKey":"dup","title":"B","estimatedHours":2},'
      '{"templateKey":"c","title":"C","estimatedHours":3},'
      '{"templateKey":"d","title":"D","estimatedHours":4},'
      '{"templateKey":"e","title":"E","estimatedHours":5}'
      ']}]}',
    ));
    final r = await AiPreparationPersonalizer(llm).personalize(req: _req());
    final data = (r as Success).data as PreparationPersonalizationResult;
    expect(data.phases.length, 1);
    // dup 第二个被丢弃；剩 A/C/D/E 共 4 条 > 3 → 截断到 3 条
    expect(data.phases[0].optionalTasks.length, 3);
    expect(data.phases[0].optionalTasks.map((t) => t.templateKey),
        ['dup', 'c', 'd']);
  });

  test('畸形 JSON 返回 Failure', () async {
    final llm = _StubLlm(const Success('not json'));
    final r = await AiPreparationPersonalizer(llm).personalize(req: _req());
    expect(r, isA<Failure<PreparationPersonalizationResult>>());
  });

  test('Llm 未配置返回 Failure', () async {
    // 对齐 MissingLlmClient：未配置时 complete() 返回
    // Failure(MissingLlmConfigurationException())。
    final llm = _StubLlm(const Failure(MissingLlmConfigurationException()));
    final r = await AiPreparationPersonalizer(llm).personalize(req: _req());
    expect(r, isA<Failure<PreparationPersonalizationResult>>());
    expect((r as Failure).error, isA<MissingLlmConfigurationException>());
  });
}
