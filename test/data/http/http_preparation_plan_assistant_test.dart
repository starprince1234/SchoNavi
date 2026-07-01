import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_preparation_plan_assistant.dart';
import 'package:scho_navi/data/http/http_preparation_plan_assistant.dart';
import 'package:scho_navi/data/mock/fake_backend.dart';
import 'package:scho_navi/domain/entities/plan_change_card.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

PreparationPlan _plan({String id = 'pp_1'}) => PreparationPlan(
  id: id,
  competition: CompetitionSnapshot(
    id: 'comp_demo',
    name: 'Demo Cup',
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
  targetDate: DateTime(2026, 5, 30),
  timelineType: CompetitionTimelineType.submission,
  defenseDate: DateTime(2026, 6, 10),
  revision: 1,
  weeklyCommitment: WeeklyCommitment.hours6to10,
  experienceLevel: ExperienceLevel.intermediate,
  status: PreparationPlanStatus.active,
  phases: [
    PreparationPhase(
      key: 'proposal_writing',
      title: '方案撰写',
      startDate: DateTime(2026, 5, 10),
      endDate: DateTime(2026, 5, 22),
      tasks: [
        PreparationTask(
          id: 'task_core_algo',
          title: '核心算法实现',
          kind: PreparationTaskKind.required,
          estimatedHours: 16,
          dueDate: DateTime(2026, 5, 15),
        ),
      ],
    ),
    PreparationPhase(
      key: 'defense_prep',
      title: '答辩准备',
      startDate: DateTime(2026, 5, 31),
      endDate: DateTime(2026, 6, 10),
      tasks: const [],
    ),
  ],
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
);

PlanAssistantRequest _req() => PlanAssistantRequest(
  planId: 'pp_1',
  calendarToday: DateTime(2026, 5, 1),
  basePlanRevision: 1,
  planSnapshot: _plan(),
  userMessage: '这周期末考没空，往后挪；答辩前留个模拟答辩',
  requestId: 'req_test',
);

void main() {
  test('HTTP 调用 fake 后端返回助手回复与改动卡', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://fake.local'));
    dio.httpClientAdapter = FakeBackendAdapter()
      ..registerPreparationAssistantHandler();
    final d = HttpPreparationPlanAssistant(dio);

    final r = await d.suggestChanges(_req());

    expect(r, isA<Success<AssistantReply>>());
    final data = (r as Success<AssistantReply>).data;
    expect(data.reply, '我整理了两项可单独确认的调整。');
    expect(data.changeSet.id, 'cs_fake_1');
    expect(data.changeSet.cards.length, 2);
    final move = data.changeSet.cards[0];
    expect(move.type, ChangeCardType.moveTask);
    // fake 的 move_task new_date=2026-05-22 落在 [2026-05-01, 2026-05-30] 内。
    expect(move.status, ChangeCardStatus.pending);
    final add = data.changeSet.cards[1];
    expect(add.type, ChangeCardType.addTask);
    // add_task due_date=2026-06-05 落在 defense_prep [2026-05-31, 2026-06-10] 内。
    expect(add.status, ChangeCardStatus.pending);
  });

  test('默认 handler map 已注册 assistant 端点（plan id pp_1，无需手动 register）', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://fake.local'));
    dio.httpClientAdapter = FakeBackendAdapter();
    final d = HttpPreparationPlanAssistant(dio);

    final r = await d.suggestChanges(_req());

    expect(r, isA<Success<AssistantReply>>());
    expect((r as Success<AssistantReply>).data.changeSet.cards.length, 2);
  });

  test('未注册的 plan id 返回 404 Failure', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://fake.local'));
    dio.httpClientAdapter = FakeBackendAdapter();
    final d = HttpPreparationPlanAssistant(dio);

    // path id 与 snapshot id 一致（满足构造校验），但后端未注册 → 404。
    final unknownPlan = _plan(id: 'pp_unknown');
    final r = await d.suggestChanges(
      PlanAssistantRequest(
        planId: 'pp_unknown',
        calendarToday: DateTime(2026, 5, 1),
        basePlanRevision: 1,
        planSnapshot: unknownPlan,
        userMessage: 'hi',
        requestId: 'req_test',
      ),
    );

    expect(r, isA<Failure<AssistantReply>>());
  });

  test('planId 与 planSnapshot.id 不一致触发构造断言', () {
    // spec §3.4：{id} 必须与 plan_snapshot.id 一致；构造时即失败。
    expect(
      () => PlanAssistantRequest(
        planId: 'pp_1',
        calendarToday: DateTime(2026, 5, 1),
        basePlanRevision: 1,
        planSnapshot: _plan(id: 'pp_other'),
        userMessage: 'hi',
        requestId: 'req_test',
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
