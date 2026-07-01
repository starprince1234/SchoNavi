import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/platform/preparation_reminder_platform.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/domain/entities/preparation_reminder.dart';
import 'package:scho_navi/features/preparation/pages/preparation_plans_page.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';
import 'package:scho_navi/features/preparation/providers/preparation_reminder_providers.dart';

PreparationPlan _plan({
  String id = 'p1',
  PreparationPlanStatus status = PreparationPlanStatus.active,
}) => PreparationPlan(
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
      officialUrl: null,
    ),
  ),
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
    GoRoute(path: '/', builder: (_, _) => const PreparationPlansPage()),
    GoRoute(
      path: '/preparation-plans/:id',
      builder: (_, state) =>
          Scaffold(body: Text('detail:${state.pathParameters['id']}')),
    ),
  ],
);

class _FakePreparationReminderPlatform
    implements PreparationReminderPlatform {
  var pinWidgetCalls = 0;
  ReminderRouteHandler? routeHandler;

  @override
  bool get isSupported => true;

  @override
  Future<ReminderNotificationStatus> getNotificationStatus() async =>
      ReminderNotificationStatus.granted;

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<bool> pinWidget() async {
    pinWidgetCalls++;
    return true;
  }

  @override
  Future<ReminderNotificationStatus> requestNotificationPermission() async =>
      ReminderNotificationStatus.granted;

  @override
  void setRouteHandler(ReminderRouteHandler? handler) {
    routeHandler = handler;
  }

  @override
  Future<void> syncSnapshot(PreparationReminderSnapshot snapshot) async {}

  @override
  Future<String?> takeInitialRoute() async => null;

  @override
  Future<void> updateSchedule(ReminderPreferences preferences) async {}
}

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

  testWidgets('默认显示进行中，归档隐藏', (t) async {
    final container = await bootstrap();
    await container
        .read(preparationPlanRepositoryProvider)
        .save(_plan(id: 'p1'));
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

  testWidgets('右上角入口可发起添加桌面小组件', (t) async {
    final fakePlatform = _FakePreparationReminderPlatform();
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        preparationReminderPlatformProvider.overrideWithValue(fakePlatform),
      ],
    );
    addTearDown(container.dispose);

    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('preparation-pin-widget-button')));
    await t.pumpAndSettle();

    expect(fakePlatform.pinWidgetCalls, 1);
    expect(find.text('已向系统发起添加桌面小组件请求'), findsOneWidget);
  });
}
