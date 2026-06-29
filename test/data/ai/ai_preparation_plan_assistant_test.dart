import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_preparation_plan_assistant.dart';
import 'package:scho_navi/domain/entities/plan_change_card.dart';
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

PreparationPlan _plan() => PreparationPlan(
      id: 'pp_1',
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
    );

Map<String, dynamic> _validReplyJson() => {
      'reply': '我整理了两项可单独确认的调整。',
      'change_set': {
        'id': 'cs_1',
        'base_plan_revision': 1,
        'cards': [
          {
            'id': 'cc_1',
            'type': 'move_task',
            'target_task_id': 'task_core_algo',
            'new_date': '2026-05-22',
            'summary': '把【核心算法实现】移到 5 月 22 日',
            'rationale': '避开期末考试周，同时仍早于提交 DDL。',
            'status': 'pending',
          },
          {
            'id': 'cc_2',
            'type': 'add_task',
            'target_phase_key': 'defense_prep',
            'new_task': {
              'title': '第二次模拟答辩',
              'estimated_hours': 3,
              'due_date': '2026-06-05',
              'note': '记录评委追问',
            },
            'summary': '答辩准备阶段新增一次模拟答辩',
            'rationale': '在正式答辩前预留复盘时间。',
            'status': 'pending',
          },
        ],
      },
    };

void main() {
  test('解析合法 JSON 返回 reply 与 pending 卡（经 validator 通过）', () async {
    final llm = _StubLlm(Success(jsonEncode(_validReplyJson())));
    final r = await AiPreparationPlanAssistant(llm).suggestChanges(_req());
    expect(r, isA<Success<AssistantReply>>());
    final data = (r as Success<AssistantReply>).data;
    expect(data.reply, '我整理了两项可单独确认的调整。');
    expect(data.changeSet.id, 'cs_1');
    expect(data.changeSet.cards.length, 2);
    final move = data.changeSet.cards[0];
    expect(move.type, ChangeCardType.moveTask);
    expect(move.status, ChangeCardStatus.pending);
    expect(move.targetTaskId, 'task_core_algo');
    final add = data.changeSet.cards[1];
    expect(add.type, ChangeCardType.addTask);
    expect(add.status, ChangeCardStatus.pending);
    expect(add.newTask?.title, '第二次模拟答辩');
  });

  test('越界卡被 validator 标 rejected，但 reply 仍为 Success', () async {
    final json = _validReplyJson();
    // move_task 新日期 2026-05-31 越出提交型非 defense_prep 合法区间
    // [calendarToday=2026-05-01, targetDate=2026-05-30]——validator 标
    // date_out_of_range。
    (json['change_set'] as Map)['cards'] = [
      {
        'id': 'cc_oob',
        'type': 'move_task',
        'target_task_id': 'task_core_algo',
        'new_date': '2026-05-31',
        'summary': '移到 DDL 后',
        'rationale': '尽量推迟。',
        'status': 'pending',
      },
    ];
    final llm = _StubLlm(Success(jsonEncode(json)));
    final r = await AiPreparationPlanAssistant(llm).suggestChanges(_req());
    expect(r, isA<Success<AssistantReply>>());
    final data = (r as Success<AssistantReply>).data;
    expect(data.changeSet.cards.length, 1);
    final card = data.changeSet.cards.first;
    expect(card.status, ChangeCardStatus.rejected);
    expect(card.rejectionCode, 'date_out_of_range');
  });

  test('畸形 JSON 返回 Failure', () async {
    final llm = _StubLlm(const Success('not json'));
    final r = await AiPreparationPlanAssistant(llm).suggestChanges(_req());
    expect(r, isA<Failure<AssistantReply>>());
    expect((r as Failure).error, isA<ServerException>());
  });

  test('Llm 未配置返回 Failure', () async {
    final llm = _StubLlm(const Failure(MissingLlmConfigurationException()));
    final r = await AiPreparationPlanAssistant(llm).suggestChanges(_req());
    expect(r, isA<Failure<AssistantReply>>());
    expect(
      (r as Failure).error,
      isA<MissingLlmConfigurationException>(),
    );
  });

  test('change_set 缺失返回 Failure', () async {
    final llm = _StubLlm(Success(jsonEncode({'reply': '你好'})));
    final r = await AiPreparationPlanAssistant(llm).suggestChanges(_req());
    expect(r, isA<Failure<AssistantReply>>());
    expect((r as Failure).error, isA<ServerException>());
  });
}
