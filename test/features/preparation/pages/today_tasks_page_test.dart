import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/pages/today_tasks_page.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';

PreparationPlan _plan({
  String id = 'p1',
  PreparationPlanStatus status = PreparationPlanStatus.active,
  DateTime? dueDate,
  DateTime? completedAt,
}) {
  final today = DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);
  return PreparationPlan(
    id: id,
    competition: const CompetitionSnapshot(
      id: 'c1',
      name: 'ACM-ICPC',
      category: '计算机类',
      rulesSummary: CompetitionRulesSummary(
        signupTime: '',
        contestTime: '',
        teamSize: '',
        format: '',
        organizer: '',
      ),
    ),
    targetDate: normalizedToday.add(const Duration(days: 30)),
    weeklyCommitment: WeeklyCommitment.hours6to10,
    experienceLevel: ExperienceLevel.beginner,
    status: status,
    phases: [
      PreparationPhase(
        key: 'basic',
        title: '基础训练',
        startDate: normalizedToday,
        endDate: normalizedToday.add(const Duration(days: 7)),
        tasks: [
          PreparationTask(
            id: 't1',
            title: '完成图论专题',
            kind: PreparationTaskKind.required,
            estimatedHours: 2,
            dueDate: dueDate ?? normalizedToday,
            completedAt: completedAt,
          ),
        ],
      ),
    ],
    createdAt: normalizedToday,
    updatedAt: normalizedToday,
  );
}

GoRouter _router({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/', builder: (_, _) => const TodayTasksPage()),
    GoRoute(
      path: '/preparation-plans',
      builder: (_, _) => const Scaffold(body: Text('plans')),
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
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('shows incomplete active tasks due today', (tester) async {
    final container = await bootstrap();
    await container
        .read(preparationPlanRepositoryProvider)
        .save(_plan(id: 'today'));
    await container
        .read(preparationPlanRepositoryProvider)
        .save(
          _plan(
            id: 'tomorrow',
            dueDate: DateTime.now().add(const Duration(days: 1)),
          ),
        );
    await container
        .read(preparationPlanRepositoryProvider)
        .save(_plan(id: 'archived', status: PreparationPlanStatus.archived));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日任务'), findsOneWidget);
    expect(find.text('完成图论专题'), findsOneWidget);
    expect(find.text('ACM-ICPC'), findsOneWidget);

    await tester.tap(find.text('完成图论专题'));
    await tester.pumpAndSettle();

    expect(find.text('detail:today'), findsOneWidget);
  });

  testWidgets('empty state links back to preparation plans', (tester) async {
    final container = await bootstrap();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天暂无待完成任务'), findsOneWidget);

    await tester.tap(find.text('查看备赛计划'));
    await tester.pumpAndSettle();

    expect(find.text('plans'), findsOneWidget);
  });
}
