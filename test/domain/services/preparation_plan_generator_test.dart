// test/domain/services/preparation_plan_generator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_preparation_personalizer.dart';
import 'package:scho_navi/data/fixtures/preparation_templates.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/domain/entities/preparation_template.dart';
import 'package:scho_navi/domain/repositories/preparation_template_provider.dart';
import 'package:scho_navi/domain/services/preparation_plan_generator.dart';

class _StaticProvider implements PreparationTemplateProvider {
  @override
  Future<PreparationTemplate> load({
    required CompetitionTimelineType timelineType,
    required bool includeDefense,
    required String category,
    required String competitionId,
  }) async =>
      defaultPreparationTemplate(timelineType, includeDefense: includeDefense);
}

class _SuccessPersonalizer implements PreparationPersonalizer {
  @override
  Future<Result<PreparationPersonalizationResult>> personalize({
    required PreparationPersonalizationRequest req,
  }) async =>
      Success(PreparationPersonalizationResult(
        phases: [
          PreparationPhasePersonalization(
            key: 'proposal_writing',
            optionalTasks: [
              PreparationOptionalTaskSuggestion(
                templateKey: 'ai_x',
                title: 'AI 建议',
                estimatedHours: 6,
              ),
            ],
            personalizedAdvice: 'AI 建议',
          ),
        ],
        globalAdvice: 'AI 全局',
      ));
}

class _FailPersonalizer implements PreparationPersonalizer {
  @override
  Future<Result<PreparationPersonalizationResult>> personalize({
    required PreparationPersonalizationRequest req,
  }) async =>
      const Failure(ServerException());
}

CompetitionSnapshot _comp() => CompetitionSnapshot(
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
    );

void main() {
  test('生成含 5 阶段 + 必做任务 + 排期日期', () async {
    final g = PreparationPlanGenerator(
      templateProvider: _StaticProvider(),
      personalizer: _SuccessPersonalizer(),
    );
    final plan = await g.generate(
      competition: _comp(),
      targetDate: DateTime(2026, 9, 1),
      weeklyCommitment: WeeklyCommitment.hours6to10,
      experienceLevel: ExperienceLevel.beginner,
      today: DateTime(2026, 6, 28),
      profile: null,
    );
    expect(plan.phases.length, 5);
    expect(
      plan.phases.every((p) => p.tasks.any((t) => t.kind == PreparationTaskKind.required)),
      isTrue,
    );
    expect(plan.phases.first.startDate, DateTime(2026, 6, 28));
    expect(plan.phases.last.endDate, DateTime(2026, 9, 1));
    // AI 可选任务被合并
    final writing = plan.phases.firstWhere((p) => p.key == 'proposal_writing');
    expect(writing.tasks.any((t) => t.templateKey == 'ai_x'), isTrue);
    expect(plan.personalizedSummary, 'AI 全局');
  });

  test('AI 失败时仍生成标准计划且必做不丢', () async {
    final g = PreparationPlanGenerator(
      templateProvider: _StaticProvider(),
      personalizer: _FailPersonalizer(),
    );
    final plan = await g.generate(
      competition: _comp(),
      targetDate: DateTime(2026, 9, 1),
      weeklyCommitment: WeeklyCommitment.hours6to10,
      experienceLevel: ExperienceLevel.experienced,
      today: DateTime(2026, 6, 28),
      profile: null,
    );
    expect(plan.phases.length, 5);
    expect(
      plan.phases.every((p) => p.tasks.any((t) => t.kind == PreparationTaskKind.required)),
      isTrue,
    );
    expect(plan.personalizedSummary, isNull);
  });

  test('临近目标日期压缩排期 + tightSchedule 标志', () async {
    final g = PreparationPlanGenerator(
      templateProvider: _StaticProvider(),
      personalizer: _FailPersonalizer(),
    );
    final plan = await g.generate(
      competition: _comp(),
      targetDate: DateTime(2026, 7, 5),
      weeklyCommitment: WeeklyCommitment.hours16plus,
      experienceLevel: ExperienceLevel.experienced,
      today: DateTime(2026, 6, 28),
      profile: null,
    );
    expect(plan.tightSchedule, isTrue);
    expect(plan.phases.length, lessThanOrEqualTo(7));
  });

  test('任务 dueDate clamp 到 [today, targetDate]', () async {
    final g = PreparationPlanGenerator(
      templateProvider: _StaticProvider(),
      personalizer: _FailPersonalizer(),
    );
    final plan = await g.generate(
      competition: _comp(),
      targetDate: DateTime(2026, 9, 1),
      weeklyCommitment: WeeklyCommitment.hours6to10,
      experienceLevel: ExperienceLevel.intermediate,
      today: DateTime(2026, 6, 28),
      profile: null,
    );
    for (final p in plan.phases) {
      for (final t in p.tasks) {
        expect(!t.dueDate.isBefore(DateTime(2026, 6, 28)), isTrue);
        expect(!t.dueDate.isAfter(DateTime(2026, 9, 1)), isTrue);
      }
    }
  });
}
