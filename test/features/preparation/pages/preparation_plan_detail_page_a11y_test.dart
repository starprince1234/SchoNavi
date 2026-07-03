import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/theme/app_theme.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/pages/preparation_plan_detail_page.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';

/// 无障碍验证（A11/B6 教训）：375 宽 + textScale 1.5 + 深色主题下，
/// 详情页（其内部已是 ListView，自带滚动）不应产生 overflow / RenderFlex
/// 异常。
///
/// 本测试 *不* 在外部再套一层 SingleChildScrollView——那只是掩盖问题。
/// 我们预置一条 plan（含多阶段任务），让倒计时、时间轴、任务清单都渲染，
/// 再直接 pump 页面本体并断言 `takeException()` 为 null。
PreparationPlan _plan() => PreparationPlan(
  id: 'p1',
  competition: CompetitionSnapshot(
    id: 'c1',
    name: 'ACM-ICPC 亚洲区域赛',
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
          note: '3 人队伍，含 1 名替补',
        ),
        PreparationTask(
          id: 't2',
          templateKey: 'role_split',
          title: '确定分工角色',
          kind: PreparationTaskKind.optional,
          estimatedHours: 1,
          dueDate: DateTime(2026, 7, 3),
        ),
      ],
    ),
    PreparationPhase(
      key: 'practice',
      title: '专项训练',
      startDate: DateTime(2026, 7, 6),
      endDate: DateTime(2026, 8, 10),
      tasks: [
        PreparationTask(
          id: 't3',
          templateKey: 'ds_training',
          title: '数据结构与算法专题训练',
          kind: PreparationTaskKind.required,
          estimatedHours: 20,
          dueDate: DateTime(2026, 8, 5),
        ),
      ],
    ),
  ],
  tightSchedule: true,
  overload: false,
  createdAt: DateTime(2026, 6, 28),
  updatedAt: DateTime(2026, 6, 28),
);

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  testWidgets('375x800 + 1.5x + dark 无 overflow', (tester) async {
    addTearDown(() {
      tester.platformDispatcher.clearAllTestValues();
      tester.view.reset();
    });
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 800);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;

    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    // 预置一条多阶段 plan，触发倒计时 + 时间轴 + 任务清单全部渲染（含
    // tightSchedule 警示横幅），最大化暴露溢出风险。
    await container.read(preparationPlanRepositoryProvider).save(_plan());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: const PreparationPlanDetailPage(planId: 'p1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('剩余'), findsOneWidget);
    expect(find.text('阶段时间轴'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('组建队伍'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('组建队伍'), findsOneWidget);
  });
}
