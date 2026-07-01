import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/plan_change_card.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/domain/repositories/preparation_plan_assistant.dart';

PreparationPlan _plan() => PreparationPlan(
  id: 'pp_1',
  competition: CompetitionSnapshot(
    id: 'comp_demo',
    name: 'Demo',
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
  weeklyCommitment: WeeklyCommitment.hours6to10,
  experienceLevel: ExperienceLevel.intermediate,
  status: PreparationPlanStatus.active,
  phases: const [],
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
);

void main() {
  test('PlanAssistantRequest 携带 requestId', () {
    final req = PlanAssistantRequest(
      planId: 'pp_1',
      calendarToday: DateTime(2026, 5, 1),
      basePlanRevision: 1,
      planSnapshot: _plan(),
      userMessage: '往后挪',
      requestId: 'req_123',
    );
    expect(req.requestId, 'req_123');
  });

  test('AssistantReply 携带 requestId', () {
    const reply = AssistantReply(
      reply: '已调整',
      changeSet: PlanChangeSet(id: 'cs_1', basePlanRevision: 1, cards: []),
      requestId: 'req_123',
    );
    expect(reply.requestId, 'req_123');
  });
}
