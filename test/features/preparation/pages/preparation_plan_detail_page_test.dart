import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/pages/preparation_plan_detail_page.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';

PreparationPlan _plan() => PreparationPlan(
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
          title: '组建队伍',
          kind: PreparationTaskKind.required,
          estimatedHours: 3,
          dueDate: DateTime(2026, 7, 1),
        ),
      ],
    ),
  ],
  tightSchedule: false,
  overload: false,
  createdAt: DateTime(2026, 6, 28),
  updatedAt: DateTime(2026, 6, 28),
);

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  /// Bootstraps a real ProviderContainer with the SharedPreferences instance
  /// so [preparationPlanRepositoryProvider] (→ localStoreProvider →
  /// sharedPreferencesProvider) resolves. Mirrors the convention used by
  /// preparation_plan_form_page_test.dart.
  Future<ProviderContainer> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('渲染倒计时+进度+时间轴+任务', (t) async {
    final container = await bootstrap();
    await container.read(preparationPlanRepositoryProvider).save(_plan());
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PreparationPlanDetailPage(planId: 'p1')),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('剩余'), findsOneWidget);
    expect(find.text('组队'), findsOneWidget);
    expect(find.text('组建队伍'), findsOneWidget);
  });

  testWidgets('勾选任务标记完成', (t) async {
    final container = await bootstrap();
    await container.read(preparationPlanRepositoryProvider).save(_plan());
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PreparationPlanDetailPage(planId: 'p1')),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(Checkbox));
    await t.pumpAndSettle();
    final plan = container
        .read(preparationPlanRepositoryProvider)
        .findById('p1')!;
    expect(plan.phases[0].tasks[0].completed, isTrue);
  });

  testWidgets('删除必做任务被阻止', (t) async {
    final container = await bootstrap();
    await container.read(preparationPlanRepositoryProvider).save(_plan());
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PreparationPlanDetailPage(planId: 'p1')),
      ),
    );
    await t.pumpAndSettle();
    // 必做任务的删除按钮不存在或禁用
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('过去阶段添加任务打开 DatePicker 不断言', (t) async {
    // 阶段 endDate 与任务 dueDate 均在今天之前；showDatePicker 会断言
    // initialDate >= firstDate，未钳制时会抛 assertion。
    final pastPlan = PreparationPlan(
      id: 'pPast',
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
      phases: [
        PreparationPhase(
          key: 'past_phase',
          title: '已过期阶段',
          // 故意设在很早以前，确保 endDate < today。
          startDate: DateTime(2020, 1, 1),
          endDate: DateTime(2020, 1, 7),
          tasks: [
            PreparationTask(
              id: 'pt1',
              templateKey: 'past_task',
              title: '过期任务',
              kind: PreparationTaskKind.optional,
              estimatedHours: 2,
              dueDate: DateTime(2020, 1, 5),
            ),
          ],
        ),
      ],
      tightSchedule: false,
      overload: false,
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );
    final container = await bootstrap();
    await container.read(preparationPlanRepositoryProvider).save(pastPlan);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PreparationPlanDetailPage(planId: 'pPast')),
      ),
    );
    await t.pumpAndSettle();
    // 打开添加任务对话框。
    await t.tap(find.text('添加任务'));
    await t.pumpAndSettle();
    // 点击日期行触发 showDatePicker；钳制后不应抛断言。
    await t.tap(find.textContaining('截止：'));
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets('详情页渲染锚点条（提交型显示提交+答辩）', (t) async {
    final plan = _plan().copyWith(
      timelineType: CompetitionTimelineType.submission,
      defenseDate: DateTime(2026, 9, 10),
    );
    final container = await bootstrap();
    await container.read(preparationPlanRepositoryProvider).save(plan);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PreparationPlanDetailPage(planId: 'p1')),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('提交'), findsOneWidget);
    expect(find.textContaining('答辩'), findsOneWidget);
  });

  testWidgets('defense_prep 阶段添加任务日期区间为提交后', (t) async {
    // defense_prep 任务应在 [targetDate+1, defenseDate] 区间；
    // 阶段 endDate 默认在答辩前，钳制后打开 DatePicker 不应抛断言。
    final plan = _plan().copyWith(
      timelineType: CompetitionTimelineType.submission,
      targetDate: DateTime(2026, 9, 1),
      defenseDate: DateTime(2026, 9, 10),
      phases: [
        PreparationPhase(
          key: 'defense_prep',
          title: '答辩准备',
          startDate: DateTime(2026, 9, 2),
          endDate: DateTime(2026, 9, 8),
          tasks: const [],
        ),
      ],
    );
    final container = await bootstrap();
    await container.read(preparationPlanRepositoryProvider).save(plan);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PreparationPlanDetailPage(planId: 'p1')),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('添加任务'));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('截止：'));
    await t.pump();
    // 钳制后初始 dueDate 落在 [targetDate+1, defenseDate]，无断言。
    expect(t.takeException(), isNull);
  });
}
