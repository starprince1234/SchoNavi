import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

void main() {
  group('PreparationTask', () {
    test('completedAt != null 即完成', () {
      final t = PreparationTask(
        id: 't1', title: '组队', kind: PreparationTaskKind.required,
        estimatedHours: 4, dueDate: DateTime(2026, 7, 1),
        completedAt: DateTime(2026, 6, 28),
      );
      expect(t.completed, isTrue);
    });
    test('completedAt null 即未完成', () {
      final t = PreparationTask(
        id: 't1', title: '组队', kind: PreparationTaskKind.required,
        estimatedHours: 4, dueDate: DateTime(2026, 7, 1),
      );
      expect(t.completed, isFalse);
    });
  });

  group('WeeklyCommitment', () {
    test('hoursPerWeek', () {
      expect(WeeklyCommitment.hours3to5.hoursPerWeek, 5);
      expect(WeeklyCommitment.hours6to10.hoursPerWeek, 10);
      expect(WeeklyCommitment.hours11to15.hoursPerWeek, 15);
      expect(WeeklyCommitment.hours16plus.hoursPerWeek, 16);
    });
  });

  group('序列化', () {
    test('plan toJson/fromJson 往返', () {
      final plan = PreparationPlan(
        id: 'p1',
        competition: CompetitionSnapshot(
          id: 'comp_icpc', name: 'ACM-ICPC', category: '计算机类',
          rulesSummary: CompetitionRulesSummary(
            signupTime: '4月', contestTime: '9-12月', teamSize: '3人',
            format: '编程', organizer: 'ACM', officialUrl: 'https://x',
          ),
        ),
        targetDate: DateTime(2026, 9, 1),
        weeklyCommitment: WeeklyCommitment.hours6to10,
        experienceLevel: ExperienceLevel.beginner,
        status: PreparationPlanStatus.active,
        phases: [
          PreparationPhase(
            key: 'team_formation', title: '组队',
            startDate: DateTime(2026, 6, 28), endDate: DateTime(2026, 7, 5),
            tasks: [
              PreparationTask(id: 't1', templateKey: 'team_form', title: '组建三人队伍',
                kind: PreparationTaskKind.required, estimatedHours: 3,
                dueDate: DateTime(2026, 7, 1), note: '找算法强的队友'),
            ],
            personalizedAdvice: '建议按算法/几何/DP 分工',
          ),
        ],
        personalizedSummary: '整体偏算法训练',
        createdAt: DateTime(2026, 6, 28),
        updatedAt: DateTime(2026, 6, 28),
        tightSchedule: false,
        overload: false,
      );
      final json = plan.toJson();
      final back = PreparationPlan.fromJson(json);
      expect(back.id, 'p1');
      expect(back.competition.name, 'ACM-ICPC');
      expect(back.weeklyCommitment, WeeklyCommitment.hours6to10);
      expect(back.phases.length, 1);
      expect(back.phases[0].tasks[0].templateKey, 'team_form');
      expect(back.phases[0].tasks[0].note, '找算法强的队友');
      expect(back.phases[0].tasks[0].completed, isFalse);
      expect(back.personalizedSummary, '整体偏算法训练');
      expect(back.tightSchedule, isFalse);
      expect(back.overload, isFalse);
    });
  });
}
