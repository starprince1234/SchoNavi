import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/widgets/preparation_anchor_bar.dart';

CompetitionSnapshot _comp() => CompetitionSnapshot(
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
);

PreparationPlan _windowPlan({
  required DateTime targetDate,
  DateTime? eventEndDate,
}) => PreparationPlan(
  id: 'pWin',
  competition: _comp(),
  targetDate: targetDate,
  timelineType: CompetitionTimelineType.eventWindow,
  eventEndDate: eventEndDate,
  weeklyCommitment: WeeklyCommitment.hours6to10,
  experienceLevel: ExperienceLevel.beginner,
  status: PreparationPlanStatus.active,
  phases: const [],
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

PreparationPlan _submissionPlan({
  required DateTime targetDate,
  DateTime? defenseDate,
}) => PreparationPlan(
  id: 'pSub',
  competition: _comp(),
  targetDate: targetDate,
  timelineType: CompetitionTimelineType.submission,
  defenseDate: defenseDate,
  weeklyCommitment: WeeklyCommitment.hours6to10,
  experienceLevel: ExperienceLevel.beginner,
  status: PreparationPlanStatus.active,
  phases: const [],
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('窗口型显示比赛起止', (t) async {
    await t.pumpWidget(
      _wrap(
        PreparationAnchorBar(
          plan: _windowPlan(
            targetDate: DateTime(2026, 5, 20),
            eventEndDate: DateTime(2026, 5, 22),
          ),
        ),
      ),
    );
    expect(find.textContaining('比赛'), findsOneWidget);
    // 区间：5/20–5/22
    expect(find.textContaining('5/20'), findsOneWidget);
    expect(find.textContaining('5/22'), findsOneWidget);
  });

  testWidgets('窗口型 eventEndDate 缺省退化为单日', (t) async {
    await t.pumpWidget(
      _wrap(
        PreparationAnchorBar(
          plan: _windowPlan(targetDate: DateTime(2026, 5, 20)),
        ),
      ),
    );
    expect(find.textContaining('比赛'), findsOneWidget);
    expect(find.textContaining('5/20'), findsOneWidget);
    // 不含区间分隔
    expect(find.textContaining('–'), findsNothing);
  });

  testWidgets('窗口型 eventEndDate == targetDate 退化为单日', (t) async {
    await t.pumpWidget(
      _wrap(
        PreparationAnchorBar(
          plan: _windowPlan(
            targetDate: DateTime(2026, 5, 20),
            eventEndDate: DateTime(2026, 5, 20),
          ),
        ),
      ),
    );
    expect(find.textContaining('比赛'), findsOneWidget);
    expect(find.textContaining('5/20'), findsOneWidget);
    expect(find.textContaining('–'), findsNothing);
  });

  testWidgets('提交型有答辩显示 DDL 与答辩', (t) async {
    await t.pumpWidget(
      _wrap(
        PreparationAnchorBar(
          plan: _submissionPlan(
            targetDate: DateTime(2026, 5, 30),
            defenseDate: DateTime(2026, 6, 10),
          ),
        ),
      ),
    );
    expect(find.textContaining('提交'), findsOneWidget);
    expect(find.textContaining('答辩'), findsOneWidget);
    expect(find.textContaining('5/30'), findsOneWidget);
    expect(find.textContaining('6/10'), findsOneWidget);
  });

  testWidgets('提交型无答辩不显示答辩段', (t) async {
    await t.pumpWidget(
      _wrap(
        PreparationAnchorBar(
          plan: _submissionPlan(targetDate: DateTime(2026, 5, 30)),
        ),
      ),
    );
    expect(find.textContaining('提交'), findsOneWidget);
    expect(find.textContaining('答辩'), findsNothing);
  });
}
