import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

void main() {
  group('PreparationTask', () {
    test('completedAt != null 即完成', () {
      final t = PreparationTask(
        id: 't1',
        title: '组队',
        kind: PreparationTaskKind.required,
        estimatedHours: 4,
        dueDate: DateTime(2026, 7, 1),
        completedAt: DateTime(2026, 6, 28),
      );
      expect(t.completed, isTrue);
    });
    test('completedAt null 即未完成', () {
      final t = PreparationTask(
        id: 't1',
        title: '组队',
        kind: PreparationTaskKind.required,
        estimatedHours: 4,
        dueDate: DateTime(2026, 7, 1),
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
          id: 'comp_icpc',
          name: 'ACM-ICPC',
          category: '计算机类',
          rulesSummary: CompetitionRulesSummary(
            signupTime: '4月',
            contestTime: '9-12月',
            teamSize: '3人',
            format: '编程',
            organizer: 'ACM',
            officialUrl: 'https://x',
          ),
        ),
        targetDate: DateTime(2026, 9, 1),
        weeklyCommitment: WeeklyCommitment.hours6to10,
        experienceLevel: ExperienceLevel.beginner,
        status: PreparationPlanStatus.active,
        phases: [
          PreparationPhase(
            key: 'team_formation',
            title: '组队',
            startDate: DateTime(2026, 6, 28),
            endDate: DateTime(2026, 7, 5),
            tasks: [
              PreparationTask(
                id: 't1',
                templateKey: 'team_form',
                title: '组建三人队伍',
                kind: PreparationTaskKind.required,
                estimatedHours: 3,
                dueDate: DateTime(2026, 7, 1),
                note: '找算法强的队友',
              ),
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

  group('PreparationPlan 双段时间模型', () {
    test(
      'toJson/fromJson 往返保留 timelineType/eventEndDate/defenseDate/revision',
      () {
        final plan = PreparationPlan(
          id: 'pp_1',
          competition: _comp(),
          targetDate: DateTime(2026, 6, 1),
          timelineType: CompetitionTimelineType.eventWindow,
          eventEndDate: DateTime(2026, 6, 3),
          defenseDate: null,
          weeklyCommitment: WeeklyCommitment.hours6to10,
          experienceLevel: ExperienceLevel.intermediate,
          status: PreparationPlanStatus.active,
          phases: const [],
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
          revision: 0,
        );
        final decoded = PreparationPlan.fromJson(plan.toJson());
        expect(decoded.timelineType, CompetitionTimelineType.eventWindow);
        expect(decoded.eventEndDate, DateTime(2026, 6, 3));
        expect(decoded.defenseDate, isNull);
        expect(decoded.revision, 0);
      },
    );

    test('旧 v1 JSON（缺新字段）默认 submission + revision 0', () {
      final legacy = <String, dynamic>{
        'id': 'pp_old',
        'competition': _comp().toJson(),
        'target_date': '2026-06-01T00:00:00.000',
        'weekly_commitment': 'hours6to10',
        'experience_level': 'intermediate',
        'status': 'active',
        'phases': <dynamic>[],
        'created_at': '2026-05-01T00:00:00.000Z',
        'updated_at': '2026-05-01T00:00:00.000Z',
        'tight_schedule': false,
        'overload': false,
      };
      final plan = PreparationPlan.fromJson(legacy);
      expect(plan.timelineType, CompetitionTimelineType.submission);
      expect(plan.eventEndDate, isNull);
      expect(plan.defenseDate, isNull);
      expect(plan.revision, 0);
    });
  });

  group('registrationDeadline', () {
    test('registrationDeadline toJson/fromJson 往返', () {
      final plan = _basePlan().copyWith(
        registrationDeadline: DateTime(2026, 8, 15),
      );
      final json = plan.toJson();
      expect(json['registration_deadline'], '2026-08-15');
      final restored = PreparationPlan.fromJson(json);
      expect(restored.registrationDeadline, DateTime(2026, 8, 15));
    });

    test('registrationDeadline 为 null 时不写入 JSON', () {
      final plan = _basePlan().copyWith(); // 不设置
      final json = plan.toJson();
      expect(json.containsKey('registration_deadline'), isFalse);
      expect(PreparationPlan.fromJson(json).registrationDeadline, isNull);
    });

    test('旧 JSON 无 registration_deadline 字段时容错为 null', () {
      final json = _basePlan().toJson();
      json.remove('registration_deadline');
      expect(PreparationPlan.fromJson(json).registrationDeadline, isNull);
    });

    test('copyWith registrationDeadline=null 清空，不传保留旧值', () {
      final plan = _basePlan().copyWith(
        registrationDeadline: DateTime(2026, 8, 15),
      );
      expect(plan.registrationDeadline, DateTime(2026, 8, 15));
      // 不传 → 保留
      final kept = plan.copyWith(targetDate: DateTime(2026, 9, 2));
      expect(kept.registrationDeadline, DateTime(2026, 8, 15));
      // 显式传 null → 清空
      final cleared = plan.copyWith(registrationDeadline: null);
      expect(cleared.registrationDeadline, isNull);
    });
  });
}

CompetitionSnapshot _comp() => CompetitionSnapshot(
  id: 'c1',
  name: '测试赛',
  category: '计算机类',
  rulesSummary: CompetitionRulesSummary(
    signupTime: '2026-01',
    contestTime: '2026-06',
    teamSize: '3',
    format: '现场',
    organizer: '某',
  ),
);

PreparationPlan _basePlan() => PreparationPlan(
  id: 'p1',
  competition: CompetitionSnapshot(
    id: 'c1',
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
  status: PreparationPlanStatus.active,
  phases: const [],
  createdAt: DateTime(2026, 6, 28),
  updatedAt: DateTime(2026, 6, 28),
);
