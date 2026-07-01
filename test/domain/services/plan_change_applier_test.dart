// test/domain/services/plan_change_applier_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/plan_change_card.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/domain/services/plan_change_applier.dart';

PreparationTask _task(
  String id, {
  PreparationTaskKind kind = PreparationTaskKind.required,
  DateTime? dueDate,
  DateTime? completedAt,
  int estimatedHours = 4,
  String? note,
}) => PreparationTask(
  id: id,
  title: '任务-$id',
  kind: kind,
  estimatedHours: estimatedHours,
  dueDate: dueDate ?? DateTime(2026, 5, 15),
  completedAt: completedAt,
  note: note,
);

PreparationPhase _phase(
  String key, {
  DateTime? startDate,
  DateTime? endDate,
  List<PreparationTask> tasks = const [],
  String? advice,
}) => PreparationPhase(
  key: key,
  title: '阶段-$key',
  startDate: startDate ?? DateTime(2026, 5, 10),
  endDate: endDate ?? DateTime(2026, 5, 22),
  tasks: tasks,
  personalizedAdvice: advice,
);

/// 提交型计划：calendarToday=2026-05-01、targetDate=2026-05-30。
/// 单阶段 proposal_writing [2026-05-10, 2026-05-22]。
PreparationPlan _plan({
  int revision = 0,
  List<PreparationPhase>? phases,
  String? personalizedSummary,
  CompetitionTimelineType timelineType = CompetitionTimelineType.submission,
  DateTime? defenseDate,
  DateTime? targetDate,
}) => PreparationPlan(
  id: 'pp_1',
  competition: CompetitionSnapshot(
    id: 'comp_1',
    name: 'C',
    category: '计算机类',
    rulesSummary: CompetitionRulesSummary(
      signupTime: '',
      contestTime: '',
      teamSize: '',
      format: '',
      organizer: '',
    ),
  ),
  targetDate: targetDate ?? DateTime(2026, 5, 30),
  timelineType: timelineType,
  defenseDate: defenseDate,
  revision: revision,
  weeklyCommitment: WeeklyCommitment.hours6to10,
  experienceLevel: ExperienceLevel.beginner,
  status: PreparationPlanStatus.active,
  phases:
      phases ??
      [
        _phase(
          'proposal_writing',
          tasks: [
            _task('t_core', kind: PreparationTaskKind.required),
            _task('t_opt', kind: PreparationTaskKind.optional),
          ],
        ),
      ],
  personalizedSummary: personalizedSummary,
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
);

PlanChangeCard _card({
  String id = 'cc_1',
  required ChangeCardType type,
  String? targetTaskId,
  String? targetPhaseKey,
  DateTime? newDate,
  NewTaskDraft? newTask,
  List<PhaseScheduleDraft>? phaseSchedule,
  String? adviceText,
  String summary = 's',
  String rationale = 'r',
}) => PlanChangeCard(
  id: id,
  type: type,
  targetTaskId: targetTaskId,
  targetPhaseKey: targetPhaseKey,
  newDate: newDate,
  newTask: newTask,
  phaseSchedule: phaseSchedule,
  adviceText: adviceText,
  summary: summary,
  rationale: rationale,
);

void main() {
  group('moveTask', () {
    test('改 dueDate 到 newDate，保留其它字段', () {
      final plan = _plan();
      final card = _card(
        type: ChangeCardType.moveTask,
        targetTaskId: 't_opt',
        newDate: DateTime(2026, 5, 20),
      );
      final res = PlanChangeApplier.applyCard(
        plan: plan,
        card: card,
        expectedRevision: 0,
        calendarToday: DateTime(2026, 5, 1),
      );
      expect(res.applied, true);
      expect(res.stale, false);
      expect(res.error, isNull);
      final moved = res.newPlan!.phases.first.tasks.firstWhere(
        (t) => t.id == 't_opt',
      );
      expect(moved.dueDate, DateTime(2026, 5, 20));
      // 另一个任务不变
      final core = res.newPlan!.phases.first.tasks.firstWhere(
        (t) => t.id == 't_core',
      );
      expect(core.dueDate, DateTime(2026, 5, 15));
    });

    test('newDate 越界时 clamp 到阶段范围', () {
      final plan = _plan();
      // 阶段 [2026-05-10, 2026-05-22]；提交型非 defense_prep 任务合法区间为
      // [calendarToday, targetDate] = [2026-05-01, 2026-05-30]。
      // 这里用阶段边界内的卡，但 newDate 落在阶段外、计划区间内 → 验证会通过；
      // 改用超出阶段边界的日期，验证 applier clamp 到阶段 endDate。
      final card = _card(
        type: ChangeCardType.moveTask,
        targetTaskId: 't_opt',
        newDate: DateTime(2026, 5, 28), // 阶段外、计划内
      );
      final res = PlanChangeApplier.applyCard(
        plan: plan,
        card: card,
        expectedRevision: 0,
        calendarToday: DateTime(2026, 5, 1),
      );
      // validator 用计划区间（非阶段边界）判定合法，故 applied=true；applier clamp 到阶段。
      expect(res.applied, true);
      final moved = res.newPlan!.phases.first.tasks.firstWhere(
        (t) => t.id == 't_opt',
      );
      expect(moved.dueDate, DateTime(2026, 5, 22));
    });
  });

  group('addTask', () {
    test('生成确定性 ID 并强制 kind=userAdded', () {
      final plan = _plan(revision: 3);
      final card = _card(
        id: 'cc_add',
        type: ChangeCardType.addTask,
        targetPhaseKey: 'proposal_writing',
        newTask: NewTaskDraft(
          title: '补充实验',
          estimatedHours: 4,
          dueDate: DateTime(2026, 5, 18),
          note: 'note',
        ),
      );
      final res = PlanChangeApplier.applyCard(
        plan: plan,
        card: card,
        expectedRevision: 3,
        calendarToday: DateTime(2026, 5, 1),
      );
      expect(res.applied, true);
      final phase = res.newPlan!.phases.firstWhere(
        (p) => p.key == 'proposal_writing',
      );
      expect(phase.tasks.length, 3);
      final added = phase.tasks.lastWhere((t) => t.id.startsWith('u_'));
      expect(added.id, 'u_3_cc_add');
      expect(added.kind, PreparationTaskKind.userAdded);
      expect(added.title, '补充实验');
      expect(added.estimatedHours, 4);
      expect(added.dueDate, DateTime(2026, 5, 18));
      expect(added.note, 'note');
      expect(added.completedAt, isNull);
    });

    test('同 plan revision + 同 card id 生成相同 ID（幂等可检测）', () {
      final plan = _plan(revision: 2);
      PlanChangeCard mk() => _card(
        id: 'cc_dup',
        type: ChangeCardType.addTask,
        targetPhaseKey: 'proposal_writing',
        newTask: NewTaskDraft(
          title: 'x',
          estimatedHours: 2,
          dueDate: DateTime(2026, 5, 18),
        ),
      );
      final r1 = PlanChangeApplier.applyCard(
        plan: plan,
        card: mk(),
        expectedRevision: 2,
        calendarToday: DateTime(2026, 5, 1),
      );
      final r2 = PlanChangeApplier.applyCard(
        plan: plan,
        card: mk(),
        expectedRevision: 2,
        calendarToday: DateTime(2026, 5, 1),
      );
      // 两次对同一 plan 应用产生的 added id 相同（调用方据此去重）。
      final id1 = r1.newPlan!.phases.first.tasks
          .lastWhere((t) => t.kind == PreparationTaskKind.userAdded)
          .id;
      final id2 = r2.newPlan!.phases.first.tasks
          .lastWhere((t) => t.kind == PreparationTaskKind.userAdded)
          .id;
      expect(id1, id2);
      expect(id1, 'u_2_cc_dup');
    });
  });

  group('deleteTask', () {
    test('移除目标任务', () {
      final plan = _plan();
      final card = _card(
        type: ChangeCardType.deleteTask,
        targetTaskId: 't_opt',
      );
      final res = PlanChangeApplier.applyCard(
        plan: plan,
        card: card,
        expectedRevision: 0,
        calendarToday: DateTime(2026, 5, 1),
      );
      expect(res.applied, true);
      final ids = res.newPlan!.phases.first.tasks.map((t) => t.id).toSet();
      expect(ids, {'t_core'});
    });
  });

  group('appendAdvice', () {
    test('有 targetPhaseKey 时追加到阶段 personalizedAdvice，不覆盖', () {
      final plan = _plan(
        phases: [
          _phase(
            'proposal_writing',
            tasks: [_task('t_core', kind: PreparationTaskKind.required)],
            advice: '原建议',
          ),
        ],
      );
      final card = _card(
        type: ChangeCardType.appendAdvice,
        targetPhaseKey: 'proposal_writing',
        adviceText: '新建议',
      );
      final res = PlanChangeApplier.applyCard(
        plan: plan,
        card: card,
        expectedRevision: 0,
        calendarToday: DateTime(2026, 5, 1),
      );
      expect(res.applied, true);
      final advice = res.newPlan!.phases.first.personalizedAdvice!;
      expect(advice, '原建议\n新建议');
    });

    test('targetPhaseKey 为 null 时追加到 personalizedSummary，不覆盖', () {
      final plan = _plan(personalizedSummary: '原总览');
      final card = _card(type: ChangeCardType.appendAdvice, adviceText: '新总览');
      final res = PlanChangeApplier.applyCard(
        plan: plan,
        card: card,
        expectedRevision: 0,
        calendarToday: DateTime(2026, 5, 1),
      );
      expect(res.applied, true);
      expect(res.newPlan!.personalizedSummary, '原总览\n新总览');
    });

    test('原 advice 为空时仅写入新文本（无前导换行）', () {
      final plan = _plan();
      final card = _card(type: ChangeCardType.appendAdvice, adviceText: '全新建议');
      final res = PlanChangeApplier.applyCard(
        plan: plan,
        card: card,
        expectedRevision: 0,
        calendarToday: DateTime(2026, 5, 1),
      );
      expect(res.applied, true);
      expect(res.newPlan!.personalizedSummary, '全新建议');
    });
  });

  group('reschedulePhase', () {
    test('更新阶段边界，未完成任务 clamp 到新区间，已完成保留原 dueDate', () {
      final plan = _plan(
        revision: 1,
        phases: [
          _phase(
            'team_formation',
            startDate: DateTime(2026, 5, 1),
            endDate: DateTime(2026, 5, 5),
            tasks: [
              _task(
                't_done',
                kind: PreparationTaskKind.required,
                dueDate: DateTime(2026, 5, 3),
                completedAt: DateTime(2026, 5, 2),
              ),
              _task(
                't_open',
                kind: PreparationTaskKind.optional,
                dueDate: DateTime(2026, 5, 5),
              ),
            ],
          ),
          _phase(
            'proposal_writing',
            startDate: DateTime(2026, 5, 6),
            endDate: DateTime(2026, 5, 22),
            tasks: [_task('t_pw', kind: PreparationTaskKind.required)],
          ),
        ],
      );
      // 把 team_formation 收窄到 [2026-05-01, 2026-05-03]。
      final card = _card(
        type: ChangeCardType.reschedulePhase,
        phaseSchedule: [
          PhaseScheduleDraft(
            phaseKey: 'team_formation',
            startDate: DateTime(2026, 5, 1),
            endDate: DateTime(2026, 5, 3),
          ),
        ],
      );
      final res = PlanChangeApplier.applyCard(
        plan: plan,
        card: card,
        expectedRevision: 1,
        calendarToday: DateTime(2026, 5, 1),
      );
      expect(res.applied, true);
      final tf = res.newPlan!.phases.firstWhere(
        (p) => p.key == 'team_formation',
      );
      expect(tf.startDate, DateTime(2026, 5, 1));
      expect(tf.endDate, DateTime(2026, 5, 3));
      final done = tf.tasks.firstWhere((t) => t.id == 't_done');
      expect(done.dueDate, DateTime(2026, 5, 3)); // 已完成保留
      final open = tf.tasks.firstWhere((t) => t.id == 't_open');
      expect(open.dueDate, DateTime(2026, 5, 3)); // clamp 到新 endDate
      // 未列出的阶段保持原边界。
      final pw = res.newPlan!.phases.firstWhere(
        (p) => p.key == 'proposal_writing',
      );
      expect(pw.startDate, DateTime(2026, 5, 6));
      expect(pw.endDate, DateTime(2026, 5, 22));
    });
  });

  group('revision / re-validation', () {
    test('expectedRevision 不匹配返回 stale，不应用', () {
      final plan = _plan(revision: 5);
      final card = _card(
        type: ChangeCardType.moveTask,
        targetTaskId: 't_opt',
        newDate: DateTime(2026, 5, 20),
      );
      final res = PlanChangeApplier.applyCard(
        plan: plan,
        card: card,
        expectedRevision: 4,
        calendarToday: DateTime(2026, 5, 1),
      );
      expect(res.stale, true);
      expect(res.applied, false);
      expect(res.newPlan, isNull);
    });

    test('卡对当前计划重新校验失败时不应用，返回 error', () {
      // 删除必做任务 → validator 拒绝。
      final plan = _plan();
      final card = _card(
        type: ChangeCardType.deleteTask,
        targetTaskId: 't_core',
      );
      final res = PlanChangeApplier.applyCard(
        plan: plan,
        card: card,
        expectedRevision: 0,
        calendarToday: DateTime(2026, 5, 1),
      );
      expect(res.applied, false);
      expect(res.stale, false);
      expect(res.error, isNotNull);
      expect(res.newPlan, isNull);
    });

    test('moveTask 目标任务不存在 → 重新校验拒绝', () {
      final plan = _plan();
      final card = _card(
        type: ChangeCardType.moveTask,
        targetTaskId: 't_missing',
        newDate: DateTime(2026, 5, 20),
      );
      final res = PlanChangeApplier.applyCard(
        plan: plan,
        card: card,
        expectedRevision: 0,
        calendarToday: DateTime(2026, 5, 1),
      );
      expect(res.applied, false);
      expect(res.error, isNotNull);
    });
  });

  test('applyCard 纯函数：不修改入参 plan', () {
    final plan = _plan();
    final before = plan.toJson();
    final card = _card(
      type: ChangeCardType.moveTask,
      targetTaskId: 't_opt',
      newDate: DateTime(2026, 5, 20),
    );
    PlanChangeApplier.applyCard(
      plan: plan,
      card: card,
      expectedRevision: 0,
      calendarToday: DateTime(2026, 5, 1),
    );
    expect(plan.toJson(), before);
  });
}
