import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/pages/preparation_plans_page.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';

PreparationPlan _plan({
  String id = 'p1',
  PreparationPlanStatus status = PreparationPlanStatus.active,
}) =>
    PreparationPlan(
      id: id,
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
              officialUrl: null)),
      targetDate: DateTime(2026, 9, 1),
      weeklyCommitment: WeeklyCommitment.hours6to10,
      experienceLevel: ExperienceLevel.beginner,
      status: status,
      phases: [
        PreparationPhase(
          key: 't',
          title: '组队',
          startDate: DateTime(2026, 6, 28),
          endDate: DateTime(2026, 7, 5),
          tasks: [
            PreparationTask(
              id: 't1',
              templateKey: 'k',
              title: '组建',
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
        GoRoute(
          path: '/',
          builder: (_, _) => const PreparationPlansPage(),
        ),
        GoRoute(
          path: '/preparation-plans/:id',
          builder: (_, state) =>
              Scaffold(body: Text('detail:${state.pathParameters['id']}')),
        ),
      ],
    );

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('默认显示进行中，归档隐藏', (t) async {
    final container = await bootstrap();
    await container.read(preparationPlanRepositoryProvider).save(_plan(id: 'p1'));
    await container
        .read(preparationPlanRepositoryProvider)
        .save(_plan(id: 'p2', status: PreparationPlanStatus.archived));
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('ACM-ICPC'), findsOneWidget);
  });

  testWidgets('切到归档筛选显示归档', (t) async {
    final container = await bootstrap();
    await container
        .read(preparationPlanRepositoryProvider)
        .save(_plan(id: 'p2', status: PreparationPlanStatus.archived));
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('已归档'));
    await t.pumpAndSettle();
    expect(find.text('ACM-ICPC'), findsOneWidget);
  });

  testWidgets('空态显示提示', (t) async {
    final container = await bootstrap();
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('暂无'), findsOneWidget);
  });
}
