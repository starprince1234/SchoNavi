import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/theme/app_theme.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/pages/preparation_plans_page.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';

/// 无障碍验证（A11/B6 教训）：375 宽 + textScale 1.5 + 深色主题下，
/// 备赛列表页（其 body 是 Column+Expanded 包 ListView.separated，已自带滚动）
/// 不应产生 overflow / RenderFlex 异常。
///
/// 本测试 *不* 在外部再套一层 SingleChildScrollView——那只是掩盖问题。
/// 我们预置一条 plan 让列表渲染真实行，再直接 pump 页面本体并断言
/// `takeException()` 为 null。
PreparationPlan _plan({String id = 'p1'}) => PreparationPlan(
  id: id,
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
      key: 'team',
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

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const PreparationPlansPage()),
    GoRoute(
      path: '/preparation-plans/:id',
      builder: (_, state) =>
          Scaffold(body: Text('detail:${state.pathParameters['id']}')),
    ),
  ],
);

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  testWidgets('375x800 + 1.5x + dark 无 overflow（预置一条 plan 渲染行）', (
    tester,
  ) async {
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

    // 预置一条 plan，确保列表渲染真实行（含 ProgressIndicator、DaysChip）。
    await container.read(preparationPlanRepositoryProvider).save(_plan());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          routerConfig: _router(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('ACM-ICPC'), findsOneWidget);
  });

  testWidgets('375x800 + 1.5x + dark 无 overflow（空态）', (tester) async {
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          routerConfig: _router(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('暂无'), findsOneWidget);
  });
}
