import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/data/mock/fake_backend.dart';
import 'package:scho_navi/domain/entities/plan_change_card.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/domain/repositories/preparation_plan_repository.dart';
import 'package:scho_navi/features/preparation/widgets/assistant_drawer.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';

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
  bool savePlan = false,
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
  if (savePlan) {
    // 仓库 save 新计划要求 revision=0，save 后自增为 1（与 fake 的
    // base_plan_revision=1 对齐）。
    await container
        .read(preparationPlanRepositoryProvider)
        .save(_plan(id: planId, revision: 0));
  }
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

  testWidgets('改动卡渲染 summary + rationale + 状态胶囊 + 启用接受按钮',
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
    // 接受按钮存在且启用（pending 时可点）。
    final acceptBtn = find.text('接受');
    expect(acceptBtn, findsWidgets);
    final button = t.widget<FilledButton>(
      find.ancestor(of: acceptBtn.first, matching: find.byType(FilledButton)),
    );
    expect(button.enabled, isTrue);
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

  // ── P4b.2：接受/拒绝 + stale 检测 ──────────────────────────────────────

  /// 发送消息 → 点接受 addTask 卡 → 仓库写入新计划（新增任务）+ 卡标「已应用」
  /// + 仓库 revision 自 1→2。（moveTask 卡因新日期早于 today 被 validator
  /// 驳回，无接受按钮；仅 addTask 卡可接受。）
  testWidgets('接受 addTask 写回计划并刷新 revision', (t) async {
    final container = await _bootstrap(savePlan: true);
    await t.pumpWidget(_harness(container));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '加一次模拟答辩');
    await t.pump();
    await t.tap(find.byIcon(Icons.arrow_upward));
    await t.pumpAndSettle();

    // 接受前仓库 revision == 1。
    final repo = container.read(preparationPlanRepositoryProvider);
    expect(repo.findById('pp_1')!.revision, 1);

    await t.tap(find.text('接受').first);
    await t.pumpAndSettle();

    // 卡标 applied（状态胶囊 + 按钮文案均出现「已应用」）。
    expect(find.text('已应用'), findsWidgets);
    // 仓库 revision 自增到 2，defense_prep 阶段新增「第二次模拟答辩」任务。
    final saved = repo.findById('pp_1')!;
    expect(saved.revision, 2);
    final defense = saved.phases.firstWhere((p) => p.key == 'defense_prep');
    expect(
      defense.tasks.any((tk) => tk.title == '第二次模拟答辩'),
      isTrue,
    );
  });

  /// 生成卡片后手工改计划（revision 自 1→2），再点接受 → revision 不匹配 →
  /// 本 change set 剩余 pending 卡全部标 stale（含被点的卡）。
  testWidgets('手工编辑后剩余卡变 stale', (t) async {
    final container = await _bootstrap(savePlan: true);
    await t.pumpWidget(_harness(container));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '往后挪');
    await t.pump();
    await t.tap(find.byIcon(Icons.arrow_upward));
    await t.pumpAndSettle();

    // 手工改计划：勾选完成任务触发 save，revision 1→2（expectedRevision 仍 1）。
    await container.read(preparationPlanRepositoryProvider).save(
          _plan(id: 'pp_1', revision: 1).copyWith(
            personalizedSummary: '手动备注',
          ),
        );

    await t.tap(find.text('接受').first);
    await t.pumpAndSettle();

    // 被点的卡标 stale（可见）；接受按钮消失（stale 卡不可接受）。
    expect(find.text('已过期'), findsWidgets);
    expect(find.textContaining('计划已变化'), findsWidgets);
    expect(find.text('接受'), findsNothing);
    // cascade：剩余 pending 卡落盘为 stale（moveTask 卡本就 rejected 不受影响）。
    final store = container.read(assistantHistoryStoreProvider);
    final persisted = await store.list('pp_1');
    final statuses = persisted.last.cardStatuses;
    expect(statuses.values, contains(ChangeCardStatus.stale));
    expect(statuses.values, isNot(contains(ChangeCardStatus.pending)));
  });

  /// 拒绝后卡标 declined + 折叠（被拒卡的 rationale 隐藏）。
  testWidgets('拒绝后卡标 declined 折叠', (t) async {
    final container = await _bootstrap(savePlan: true);
    await t.pumpWidget(_harness(container));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '往后挪');
    await t.pump();
    await t.tap(find.byIcon(Icons.arrow_upward));
    await t.pumpAndSettle();

    await t.tap(find.text('拒绝').first);
    await t.pumpAndSettle();

    expect(find.text('已忽略'), findsOneWidget);
    // 撤销入口存在。
    expect(find.textContaining('撤销'), findsOneWidget);
    // 被拒卡落盘为 declined。
    final store = container.read(assistantHistoryStoreProvider);
    final persisted = await store.list('pp_1');
    expect(
      persisted.last.cardStatuses.values,
      contains(ChangeCardStatus.declined),
    );
  });

  /// 保存失败（ConflictException）卡保持 pending + 显示错误。
  testWidgets('保存失败卡保持 pending', (t) async {
    final plan = _plan();
    final fakeRepo = _ConflictRepo(plan);
    final prefs = await SharedPreferences.getInstance();
    final dio = Dio(BaseOptions(baseUrl: 'https://fake.local'))
      ..httpClientAdapter = FakeBackendAdapter();
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
        preparationPlanRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(dio.close);

    await t.pumpWidget(_harness(container));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '往后挪');
    await t.pump();
    await t.tap(find.byIcon(Icons.arrow_upward));
    await t.pumpAndSettle();

    await t.tap(find.text('接受').first);
    await t.pumpAndSettle();

    // 卡仍 pending（待确认），接受按钮仍可点，错误文案可见。
    expect(find.text('待确认'), findsWidgets);
    expect(find.textContaining('数据已变化'), findsOneWidget);
  });

  /// 已 applied 的卡再点接受幂等（不重复写计划、revision 不再变）。
  testWidgets('已应用卡再点接受幂等', (t) async {
    final container = await _bootstrap(savePlan: true);
    await t.pumpWidget(_harness(container));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '往后挪');
    await t.pump();
    await t.tap(find.byIcon(Icons.arrow_upward));
    await t.pumpAndSettle();

    await t.tap(find.text('接受').first);
    await t.pumpAndSettle();
    final repo = container.read(preparationPlanRepositoryProvider);
    expect(repo.findById('pp_1')!.revision, 2);

    // 再次点「已应用」态的卡——按钮已禁用，无新写入。
    expect(find.text('接受'), findsNothing);
    expect(repo.findById('pp_1')!.revision, 2);
  });
}

/// 始终抛 [ConflictException] 的仓库，用于测试保存失败分支。
class _ConflictRepo implements PreparationPlanRepository {
  _ConflictRepo(this._plan);

  final PreparationPlan _plan;

  @override
  PreparationPlan? findById(String id) => id == _plan.id ? _plan : null;

  @override
  List<PreparationPlan> list() => [_plan];

  @override
  PreparationPlan? activeForCompetition(String competitionId) => _plan;

  @override
  Stream<List<PreparationPlan>> watch() async* {
    yield [_plan];
  }

  @override
  Future<PreparationPlan> save(PreparationPlan plan) async {
    throw const ConflictException();
  }

  @override
  Future<void> archive(String id) async {}

  @override
  Future<void> delete(String id) async {}
}
