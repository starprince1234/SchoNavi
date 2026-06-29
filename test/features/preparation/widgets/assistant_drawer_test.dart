import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/mock/fake_backend.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/widgets/assistant_drawer.dart';

/// 助手抽屉 widget 测试（P4a.5）。
///
/// **Fake plan-id 耦合说明：** FakeBackendAdapter 按 `(method, path)` 精确匹配，
/// assistant 端点默认仅注册 plan id `pp_1`。本测试用 plan id `pp_1` 走默认注册，
/// 避免手动注册（另一用例演示对自定义 plan id 显式注册）。
PreparationPlan _plan({String id = 'pp_1', int revision = 1}) => PreparationPlan(
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
      revision: revision,
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

Future<ProviderContainer> _bootstrap({
  String planId = 'pp_1',
  bool registerCustomPlanId = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final dio = Dio(BaseOptions(baseUrl: 'https://fake.local'))
    ..httpClientAdapter = FakeBackendAdapter();
  if (registerCustomPlanId) {
    (dio.httpClientAdapter as FakeBackendAdapter)
        .registerPreparationAssistantHandler(planId: planId);
  }
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialAppConfigProvider.overrideWithValue(
        AppConfig(
          dataSource: DataSource.http,
          api: const ApiConfig(baseUrl: 'https://fake.local'),
        ),
      ),
      dioProvider.overrideWithValue(dio),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(dio.close);
  return container;
}

Widget _harness(ProviderContainer container, {String planId = 'pp_1'}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: PreparationAssistantDrawer(
            planId: planId,
            plan: _plan(id: planId),
          ),
        ),
      ),
    );

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  testWidgets('发送消息后渲染 AI 回复与两张改动卡', (t) async {
    final container = await _bootstrap();
    await t.pumpWidget(_harness(container));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '这周期末考没空，往后挪');
    await t.pump();
    await t.tap(find.byIcon(Icons.arrow_upward));
    await t.pumpAndSettle();

    // AI 回复（来自 fake handler 固定文案）。
    expect(find.textContaining('我整理了两项可单独确认的调整'), findsOneWidget);
    // 两张改动卡 summary。
    expect(find.textContaining('移到 5 月 22 日'), findsOneWidget);
    expect(find.textContaining('模拟答辩'), findsOneWidget);
    // 用户消息也渲染。
    expect(find.textContaining('这周期末考没空'), findsOneWidget);
  });

  testWidgets('改动卡渲染 summary + rationale + 状态胶囊 + 禁用接受按钮',
      (t) async {
    final container = await _bootstrap();
    await t.pumpWidget(_harness(container));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '帮我把算法实现后移');
    await t.pump();
    await t.tap(find.byIcon(Icons.arrow_upward));
    await t.pumpAndSettle();

    // rationale 出现（第一张卡）。
    expect(find.textContaining('避开期末考试周'), findsOneWidget);
    // 状态胶囊「待确认」。
    expect(find.text('待确认'), findsWidgets);
    // 接受按钮存在且禁用。
    final acceptBtn = find.text('接受');
    expect(acceptBtn, findsWidgets);
    final button = t.widget<FilledButton>(
      find.ancestor(of: acceptBtn.first, matching: find.byType(FilledButton)),
    );
    expect(button.enabled, isFalse);
  });

  testWidgets('自定义 plan id 须显式注册 fake handler', (t) async {
    // plan id 非 pp_1，未注册 → 404 → 走 Failure 分支渲染错误态文案。
    final container = await _bootstrap(planId: 'pp_custom');
    await t.pumpWidget(_harness(container, planId: 'pp_custom'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '随便问');
    await t.pump();
    await t.tap(find.byIcon(Icons.arrow_upward));
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 50));

    // Failure 分支：渲染 P0 错误态（_AssistantErrorView 固定文案）+ 无改动卡。
    expect(find.textContaining('生成失败'), findsOneWidget);
    expect(find.textContaining('移到 5 月 22 日'), findsNothing);
  });

  testWidgets('注册自定义 plan id 后可正常返回卡片', (t) async {
    final container = await _bootstrap(
      planId: 'pp_custom',
      registerCustomPlanId: true,
    );
    await t.pumpWidget(_harness(container, planId: 'pp_custom'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '随便问');
    await t.pump();
    await t.tap(find.byIcon(Icons.arrow_upward));
    await t.pumpAndSettle();

    expect(find.textContaining('我整理了两项可单独确认的调整'), findsOneWidget);
    expect(find.textContaining('移到 5 月 22 日'), findsOneWidget);
  });

  testWidgets('历史轮次渲染（追加后再次打开仍在）', (t) async {
    final container = await _bootstrap();
    await t.pumpWidget(_harness(container));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '第一轮提问');
    await t.pump();
    await t.tap(find.byIcon(Icons.arrow_upward));
    await t.pumpAndSettle();

    // 历史已落盘：重新挂载同 container 的抽屉仍能看到上一轮。
    await t.pumpWidget(_harness(container));
    await t.pumpAndSettle();
    expect(find.textContaining('第一轮提问'), findsOneWidget);
    expect(find.textContaining('我整理了两项可单独确认的调整'), findsOneWidget);
  });
}
