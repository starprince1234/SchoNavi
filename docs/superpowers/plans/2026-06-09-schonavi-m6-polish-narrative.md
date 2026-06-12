# SchoNavi M6 · 打磨 + AI 能力可视化 + APK + 作品说明 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把项目从"功能可用"抬到"评委一眼看懂 AI 在哪、好用、完整可交付"——运行时切换数据源、AI 调用透明化、设置页、首启引导、UI 打磨、APK 构建与作品说明文档。直接服务四项评分（界面/交互创新、作品完成度、大模型应用能力显式可视化）。

**Architecture:** `appConfigProvider` 由 `Provider` 改 `NotifierProvider`（`AppConfigController`），初值经新 `initialAppConfigProvider` 注入，支持运行时在 `mock`/`ai` 间切换与开关演示模式；仓储 provider 已 `ref.watch(appConfigProvider)`，切换后自动重建。新增 `LlmTrace` + `TracingLlmClient` 装饰器（仅在 `featureFlags.showAiTrace` 演示模式包裹 `DeepSeekLlmClient`，记录最近一次调用快照到 `aiTraceProvider`），推荐结果页加「查看 AI 详情」折叠区。新增 `features/settings/`（`/settings`）与 `features/onboarding/`（`/onboarding` + 首启重定向）。UI/主题/文案打磨、APK、作品说明为收尾。

**Tech Stack:** Flutter 3.44 / Dart 3.12；`flutter_riverpod ^3.3.1`（手写 provider，`Notifier`/`NotifierProvider`）；`go_router ^17.3.0`（`redirect`）；M1 `LlmClient` + M2 `stream`。无新依赖。

**Spec 依据:** `docs/superpowers/specs/2026-06-09-schonavi-m6-polish-narrative-design.md`。

**前置条件（已核实落地）:** M1/M2 已实现（`LlmClient.complete` + `stream`、`DeepSeekLlmClient`、`DataSource.mock|ai|http` DI、`appConfigProvider`=`Provider<AppConfig>`、`localStoreProvider`/`LocalStore.getBool/setBool/remove`、`favoriteRepositoryProvider.list()/remove`、`historyRepositoryProvider.clear()`）。`flutter test` 全绿，分支 `iter1`。M3/M4/M5 视进度纳入（哪些做了就在 §F 文案/演示中展示哪些，本计划不依赖其落地）。

> **范围说明（spec 顶部建议拆 2-3 plan）：** 本计划把**有逻辑、可 TDD** 的部分放前面（Task A 运行时配置、Task B AI trace 核心、Task C AI 详情面板、Task D 设置页、Task E 引导/Splash），把**纯打磨/交付**放后面（Task F UI 打磨、Task G APK、Task H 作品说明）。可按 A-E / F-H 两批分别执行与验收。

**已知破坏性改动（务必先读）：** `appConfigProvider` 由 `Provider<AppConfig>` 改 `NotifierProvider`。仅两处用 `appConfigProvider.overrideWithValue(...)`：`lib/main.dart` 与 `test/core/di/ai_providers_test.dart`，本计划 Task A 一并改为 override 新的 `initialAppConfigProvider`。若 M3/M4/M5 已落地，其 `*_provider_test` 的 ai 用例同样需把 `appConfigProvider.overrideWithValue` 改为 `initialAppConfigProvider.overrideWithValue`（各计划已留注）。新增的首启重定向会影响既有 3 个测试（Task E Step 处理）。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `lib/core/config/app_config.dart` | **改**：`FeatureFlags.showAiTrace` + `copyWith`；`AppConfig.copyWith`；`initialAppConfigProvider`；`AppConfigController` + `appConfigProvider`(NotifierProvider) |
| `lib/main.dart` | **改**：override `initialAppConfigProvider` |
| `test/core/di/ai_providers_test.dart` | **改**：override 改 `initialAppConfigProvider` |
| `test/core/config/app_config_controller_test.dart` | 切 ai 仅有 key 允许 / 切换生效 / demo 开关 |
| `lib/core/ai/llm_trace.dart` | 新：`LlmTrace` + `TracingLlmClient` + `AiTraceController` |
| `lib/core/di/providers.dart` | **改**：`aiTraceProvider` + `llmClientProvider` 演示模式包裹 |
| `test/core/ai/llm_trace_test.dart` | 记录 model/messages/raw；失败不记录；provider 包裹切换 |
| `lib/features/recommendation/pages/recommendation_page.dart` | **改**：底部「查看 AI 详情」折叠区（仅演示模式） |
| `test/features/recommendation/ai_trace_panel_test.dart` | 演示模式 + 有 trace → 面板可展开显示 model |
| `lib/features/settings/pages/settings_page.dart` | 新：数据源/模型/演示模式/清除本地/关于 |
| `lib/core/router/app_router.dart` | **改**：`/settings`、`/onboarding` 路由 + 首启 `redirect` |
| `lib/features/home/pages/home_page.dart` | **改**：AppBar 加设置入口 |
| `test/features/settings/settings_page_test.dart` | 数据源切换 / 无 key 置灰 / demo 开关 |
| `lib/features/onboarding/pages/onboarding_page.dart` | 新：首启引导，写 `seen_onboarding` |
| `test/features/onboarding/onboarding_test.dart` | 点「开始使用」写标记并跳首页 |
| `test/core/router/splash_redirect_test.dart` | 未读引导→/onboarding；已读→/home |
| `test/core/router/app_router_test.dart` | **改**：mock prefs 预置 `seen_onboarding:true` |
| `test/core/router/chat_route_test.dart` | **改**：同上 |
| `test/app_e2e_test.dart` | **改**：同上 |
| `docs/作品说明.md` | 新：选题/架构/大模型能力清单/评分对照/演示脚本 |

---

## Task A: 运行时配置（appConfigProvider → NotifierProvider）

**Files:**
- Modify: `lib/core/config/app_config.dart`
- Modify: `lib/main.dart`
- Modify: `test/core/di/ai_providers_test.dart`
- Test: `test/core/config/app_config_controller_test.dart`

- [ ] **Step 1: 写失败测试 `test/core/config/app_config_controller_test.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';

ProviderContainer _c(AppConfig initial) => ProviderContainer(
  overrides: [initialAppConfigProvider.overrideWithValue(initial)],
);

void main() {
  test('默认初值 → mock', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(appConfigProvider).dataSource, DataSource.mock);
  });

  test('初值有 key → ai', () {
    final c = _c(AppConfig.resolve(apiKey: 'sk-test'));
    addTearDown(c.dispose);
    expect(c.read(appConfigProvider).dataSource, DataSource.ai);
  });

  test('无 key 时切 ai 被拒（保持 mock）', () {
    final c = _c(AppConfig.resolve(apiKey: ''));
    addTearDown(c.dispose);
    c.read(appConfigProvider.notifier).setDataSource(DataSource.ai);
    expect(c.read(appConfigProvider).dataSource, DataSource.mock);
  });

  test('有 key 时可在 ai/mock 间切换', () {
    final c = _c(AppConfig.resolve(apiKey: 'sk-test'));
    addTearDown(c.dispose);
    final ctrl = c.read(appConfigProvider.notifier);
    ctrl.setDataSource(DataSource.mock);
    expect(c.read(appConfigProvider).dataSource, DataSource.mock);
    ctrl.setDataSource(DataSource.ai);
    expect(c.read(appConfigProvider).dataSource, DataSource.ai);
  });

  test('setShowAiTrace 开关演示模式', () {
    final c = _c(const AppConfig());
    addTearDown(c.dispose);
    expect(c.read(appConfigProvider).featureFlags.showAiTrace, isFalse);
    c.read(appConfigProvider.notifier).setShowAiTrace(true);
    expect(c.read(appConfigProvider).featureFlags.showAiTrace, isTrue);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/core/config/app_config_controller_test.dart`
Expected: FAIL（`initialAppConfigProvider`/`AppConfigController`/`setDataSource` 不存在）。

- [ ] **Step 3: 用以下完整内容替换 `lib/core/config/app_config.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DataSource { mock, ai, http }

class FeatureFlags {
  const FeatureFlags({this.showMatchScore = false, this.showAiTrace = false});

  final bool showMatchScore;
  final bool showAiTrace; // 演示模式：记录并展示 AI 调用快照

  FeatureFlags copyWith({bool? showMatchScore, bool? showAiTrace}) =>
      FeatureFlags(
        showMatchScore: showMatchScore ?? this.showMatchScore,
        showAiTrace: showAiTrace ?? this.showAiTrace,
      );
}

class LlmConfig {
  const LlmConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.deepseek.com',
    this.model = 'deepseek-chat',
  });

  final String apiKey;
  final String baseUrl;
  final String model;

  bool get isConfigured => apiKey.isNotEmpty;
}

class AppConfig {
  const AppConfig({
    this.dataSource = DataSource.mock,
    this.appVersion = '0.1.0',
    this.featureFlags = const FeatureFlags(),
    this.llm = const LlmConfig(apiKey: ''),
  });

  final DataSource dataSource;
  final String appVersion;
  final FeatureFlags featureFlags;
  final LlmConfig llm;

  AppConfig copyWith({
    DataSource? dataSource,
    String? appVersion,
    FeatureFlags? featureFlags,
    LlmConfig? llm,
  }) => AppConfig(
    dataSource: dataSource ?? this.dataSource,
    appVersion: appVersion ?? this.appVersion,
    featureFlags: featureFlags ?? this.featureFlags,
    llm: llm ?? this.llm,
  );

  factory AppConfig.resolve({
    required String apiKey,
    String baseUrl = 'https://api.deepseek.com',
    String model = 'deepseek-chat',
    String appVersion = '0.1.0',
  }) {
    final llm = LlmConfig(apiKey: apiKey, baseUrl: baseUrl, model: model);
    return AppConfig(
      dataSource: llm.isConfigured ? DataSource.ai : DataSource.mock,
      appVersion: appVersion,
      llm: llm,
    );
  }
}

/// 启动注入的初值（main 用 dart-define 解析后 override；测试可 override）。
/// 未 override 时为默认 mock 配置。
final initialAppConfigProvider = Provider<AppConfig>((ref) => const AppConfig());

/// 运行时可变的应用配置：允许评委现场在 mock/ai 间切换、开关演示模式。
class AppConfigController extends Notifier<AppConfig> {
  @override
  AppConfig build() => ref.watch(initialAppConfigProvider);

  /// 切数据源；切 ai 仅在已配置 key 时允许（否则忽略）。
  void setDataSource(DataSource ds) {
    if (ds == DataSource.ai && !state.llm.isConfigured) return;
    state = state.copyWith(dataSource: ds);
  }

  void setShowAiTrace(bool enabled) {
    state = state.copyWith(
      featureFlags: state.featureFlags.copyWith(showAiTrace: enabled),
    );
  }
}

final appConfigProvider = NotifierProvider<AppConfigController, AppConfig>(
  AppConfigController.new,
);
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/core/config/app_config_controller_test.dart test/core/config/app_config_test.dart`
Expected: PASS（控制器 5 个 + 既有 `app_config_test` 2 个；`AppConfig.resolve` 未改，旧测试仍绿）。

- [ ] **Step 5: 改 `lib/main.dart`——override `initialAppConfigProvider`**

把：
```dart
        appConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: _apiKey, baseUrl: _baseUrl, model: _model),
        ),
```
替换为：
```dart
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: _apiKey, baseUrl: _baseUrl, model: _model),
        ),
```
（`appConfigProvider` 现为 `NotifierProvider`，初值经 `initialAppConfigProvider` 注入。其余不变。）

- [ ] **Step 6: 改 `test/core/di/ai_providers_test.dart`——override 改 `initialAppConfigProvider`**

把该文件中：
```dart
        appConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: 'sk-test'),
        ),
```
替换为：
```dart
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: 'sk-test'),
        ),
```

- [ ] **Step 7: 验证并提交**

Run: `flutter analyze && flutter test test/core/ test/core/di/ai_providers_test.dart`
Expected: analyze 无 error；全绿（NotifierProvider 改造不破坏既有 DI/路由测试——除首启重定向相关，留待 Task E）。
```bash
git add lib/core/config/app_config.dart lib/main.dart test/core/di/ai_providers_test.dart test/core/config/app_config_controller_test.dart
git commit -m "feat: runtime AppConfigController (NotifierProvider) + demo flag (M6)"
```

---

## Task B: AI 调用快照（LlmTrace + TracingLlmClient）

**Files:**
- Create: `lib/core/ai/llm_trace.dart`
- Modify: `lib/core/di/providers.dart`
- Test: `test/core/ai/llm_trace_test.dart`

- [ ] **Step 1: 写失败测试 `test/core/ai/llm_trace_test.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/deepseek_llm_client.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/ai/llm_trace.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';

class _StubLlm implements LlmClient {
  _StubLlm(this._result);

  final Result<String> _result;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async => _result;

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => const Stream.empty();
}

void main() {
  test('complete 成功 → 记录 model/messages/raw', () async {
    LlmTrace? captured;
    final client = TracingLlmClient(
      delegate: _StubLlm(const Success('原始返回')),
      model: 'deepseek-chat',
      onTrace: (t) => captured = t,
    );
    final res = await client.complete(
      messages: const [LlmMessage('user', '你好')],
      jsonMode: true,
    );
    expect((res as Success).data, '原始返回');
    expect(captured, isNotNull);
    expect(captured!.model, 'deepseek-chat');
    expect(captured!.rawResponse, '原始返回');
    expect(captured!.messages.single.content, '你好');
    expect(captured!.elapsedMs, greaterThanOrEqualTo(0));
  });

  test('complete 失败 → 不记录', () async {
    LlmTrace? captured;
    final client = TracingLlmClient(
      delegate: _StubLlm(const Failure(ServerException())),
      model: 'm',
      onTrace: (t) => captured = t,
    );
    await client.complete(messages: const [LlmMessage('user', 'x')]);
    expect(captured, isNull);
  });

  test('llmClientProvider：演示模式关 → DeepSeekLlmClient', () {
    final c = ProviderContainer(
      overrides: [
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: 'sk-test'),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(llmClientProvider), isA<DeepSeekLlmClient>());
  });

  test('llmClientProvider：演示模式开 → TracingLlmClient', () {
    final c = ProviderContainer(
      overrides: [
        initialAppConfigProvider.overrideWithValue(
          const AppConfig(
            dataSource: DataSource.ai,
            featureFlags: FeatureFlags(showAiTrace: true),
            llm: LlmConfig(apiKey: 'sk-test'),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(llmClientProvider), isA<TracingLlmClient>());
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/core/ai/llm_trace_test.dart`
Expected: FAIL（`llm_trace.dart`/`aiTraceProvider`/演示模式包裹 不存在）。

- [ ] **Step 3: 实现 `lib/core/ai/llm_trace.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../result/result.dart';
import 'llm_client.dart';

/// 最近一次大模型调用快照（仅演示模式记录，用于"AI 透明化"展示）。
class LlmTrace {
  const LlmTrace({
    required this.model,
    required this.messages,
    required this.rawResponse,
    required this.elapsedMs,
  });

  final String model;
  final List<LlmMessage> messages;
  final String rawResponse;
  final int elapsedMs;
}

/// 装饰器：包裹任意 [LlmClient]，在 complete 成功时把调用快照交给 [onTrace]。
/// 流式 [stream] 直接透传，不记录快照。默认不在生产路径启用（见 llmClientProvider）。
class TracingLlmClient implements LlmClient {
  TracingLlmClient({
    required this.delegate,
    required this.model,
    required this.onTrace,
  });

  final LlmClient delegate;
  final String model;
  final void Function(LlmTrace trace) onTrace;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    final sw = Stopwatch()..start();
    final res = await delegate.complete(
      messages: messages,
      jsonMode: jsonMode,
      temperature: temperature,
    );
    sw.stop();
    if (res is Success<String>) {
      onTrace(
        LlmTrace(
          model: model,
          messages: messages,
          rawResponse: res.data,
          elapsedMs: sw.elapsedMilliseconds,
        ),
      );
    }
    return res;
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => delegate.stream(messages: messages, temperature: temperature);
}

/// 持有最近一次 [LlmTrace]，供演示页面 watch。默认 null。
class AiTraceController extends Notifier<LlmTrace?> {
  @override
  LlmTrace? build() => null;

  void record(LlmTrace trace) => state = trace;

  void clear() => state = null;
}

final aiTraceProvider = NotifierProvider<AiTraceController, LlmTrace?>(
  AiTraceController.new,
);
```

- [ ] **Step 4: 在 `lib/core/di/providers.dart` 接入演示模式包裹**

在顶部 import 区追加：
```dart
import '../ai/llm_trace.dart';
```
把既有 `llmClientProvider` 整体替换为：
```dart
final llmClientProvider = Provider<LlmClient>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final base = DeepSeekLlmClient(
    dio: ref.watch(dioProvider),
    apiKey: cfg.llm.apiKey,
    baseUrl: cfg.llm.baseUrl,
    model: cfg.llm.model,
  );
  if (!cfg.featureFlags.showAiTrace) return base;
  return TracingLlmClient(
    delegate: base,
    model: cfg.llm.model,
    onTrace: (trace) => ref.read(aiTraceProvider.notifier).record(trace),
  );
});
```
（`aiTraceProvider` 由 `llm_trace.dart` 导出，import 已加。）

- [ ] **Step 5: 运行测试，确认通过**

Run: `flutter test test/core/ai/llm_trace_test.dart`
Expected: PASS（4 个）。

- [ ] **Step 6: 提交**

```bash
git add lib/core/ai/llm_trace.dart lib/core/di/providers.dart test/core/ai/llm_trace_test.dart
git commit -m "feat: LlmTrace + TracingLlmClient + aiTraceProvider (demo-only) (M6)"
```

---

## Task C: 推荐结果页「查看 AI 详情」折叠区

**Files:**
- Modify: `lib/features/recommendation/pages/recommendation_page.dart`
- Test: `test/features/recommendation/ai_trace_panel_test.dart`

- [ ] **Step 1: 写失败测试 `test/features/recommendation/ai_trace_panel_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/ai/llm_trace.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/repositories/recommendation_repository.dart';
import 'package:scho_navi/features/recommendation/pages/recommendation_page.dart';

class _FakeRecRepo implements RecommendationRepository {
  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    String? sessionId,
  }) async => Success(
    const RecommendationResult(
      sessionId: 's1',
      queryUnderstanding: QueryUnderstanding(
        researchInterests: ['医学影像'],
        preferredLocations: [],
        preferredUniversities: [],
        uncertainties: [],
      ),
      recommendations: [
        Recommendation(
          professorId: 'p_001',
          name: '张三',
          university: '上海交通大学',
          college: 'C',
          title: '教授',
          researchFields: ['医学影像'],
          reason: '方向相关',
          limitations: [],
        ),
      ],
      followUpQuestions: [],
    ),
  );
}

Widget _wrap(WidgetRef Function(ProviderContainer) seed) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const RecommendationPage(prompt: '医学影像'),
      ),
      GoRoute(path: '/professor/:id', builder: (_, _) => const Placeholder()),
    ],
  );
  return ProviderScope(
    overrides: [
      initialAppConfigProvider.overrideWithValue(
        const AppConfig(
          dataSource: DataSource.ai,
          featureFlags: FeatureFlags(showAiTrace: true),
          llm: LlmConfig(apiKey: 'sk-test'),
        ),
      ),
      recommendationRepositoryProvider.overrideWithValue(_FakeRecRepo()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('演示模式 + 有 trace → 展开显示 model', (tester) async {
    await tester.pumpWidget(_wrap((c) => throw UnimplementedError()));
    await tester.pumpAndSettle();

    // 注入一条 trace（模拟推荐调用已记录）
    final element = tester.element(find.byType(RecommendationPage));
    final container = ProviderScope.containerOf(element);
    container.read(aiTraceProvider.notifier).record(
      const LlmTrace(
        model: 'deepseek-chat',
        messages: [LlmMessage('system', 'sys'), LlmMessage('user', '医学影像')],
        rawResponse: '{"recommendations":[]}',
        elapsedMs: 123,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('查看 AI 详情'), findsOneWidget);
    await tester.tap(find.text('查看 AI 详情'));
    await tester.pumpAndSettle();

    expect(find.textContaining('deepseek-chat'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/features/recommendation/ai_trace_panel_test.dart`
Expected: FAIL（推荐页还没有「查看 AI 详情」）。

- [ ] **Step 3: 改 `lib/features/recommendation/pages/recommendation_page.dart`**

在 import 区追加：
```dart
import '../../../core/ai/llm_client.dart';
import '../../../core/ai/llm_trace.dart';
```
在 `data:` 分支返回的 `ListView` 的 `children:` 列表，把推荐卡片 `...result.recommendations.map(...)` 之后追加一个折叠区（即在该 `map` 闭合 `),` 之后、`ListView` 的 `],` 之前插入）：
```dart
              const _AiTracePanel(),
```
然后在文件末尾（`_RecommendationPageState` 类之外）追加：
```dart
/// 仅演示模式（showAiTrace）且已有最近调用快照时显示，体现"AI 透明化"。
class _AiTracePanel extends ConsumerWidget {
  const _AiTracePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTrace = ref.watch(
      appConfigProvider.select((c) => c.featureFlags.showAiTrace),
    );
    final trace = ref.watch(aiTraceProvider);
    if (!showTrace || trace == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.science_outlined),
        title: const Text('查看 AI 详情'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('模型：${trace.model}（${trace.elapsedMs} ms）'),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('实际 prompt', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final m in trace.messages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: SelectableText('[${m.role}] ${m.content}'),
            ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('原始返回', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SelectableText(trace.rawResponse),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/features/recommendation/ai_trace_panel_test.dart test/features/recommendation/recommendation_page_test.dart`
Expected: PASS（本用例 1 个 + 既有推荐页测试不回归——非演示模式 `_AiTracePanel` 返回空白，无影响）。

- [ ] **Step 5: 提交**

```bash
git add lib/features/recommendation/pages/recommendation_page.dart test/features/recommendation/ai_trace_panel_test.dart
git commit -m "feat: AI trace panel on recommendation page (demo-only) (M6)"
```

---

## Task D: 设置页（/settings）+ 首页入口

**Files:**
- Create: `lib/features/settings/pages/settings_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/home/pages/home_page.dart`
- Test: `test/features/settings/settings_page_test.dart`

- [ ] **Step 1: 写失败测试 `test/features/settings/settings_page_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/settings/pages/settings_page.dart';

Future<Widget> _wrap(AppConfig initial) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialAppConfigProvider.overrideWithValue(initial),
    ],
    child: const MaterialApp(home: SettingsPage()),
  );
}

void main() {
  testWidgets('无 key 时 AI 开关置灰并提示', (tester) async {
    await tester.pumpWidget(await _wrap(AppConfig.resolve(apiKey: '')));
    await tester.pumpAndSettle();

    final sw = tester.widget<SwitchListTile>(
      find.byKey(const Key('settings-ai-switch')),
    );
    expect(sw.onChanged, isNull); // 置灰
    expect(find.textContaining('未配置'), findsOneWidget);
  });

  testWidgets('有 key 时切 AI 开关 → dataSource=ai', (tester) async {
    final widget = await _wrap(AppConfig.resolve(apiKey: 'sk-test'));
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // resolve 有 key 初值即 ai，先关到 mock 再开，验证开关生效
    await tester.tap(find.byKey(const Key('settings-ai-switch')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    expect(container.read(appConfigProvider).dataSource, DataSource.mock);

    await tester.tap(find.byKey(const Key('settings-ai-switch')));
    await tester.pumpAndSettle();
    expect(container.read(appConfigProvider).dataSource, DataSource.ai);
  });

  testWidgets('演示模式开关 → showAiTrace', (tester) async {
    await tester.pumpWidget(await _wrap(AppConfig.resolve(apiKey: 'sk-test')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-demo-switch')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    expect(container.read(appConfigProvider).featureFlags.showAiTrace, isTrue);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/features/settings/settings_page_test.dart`
Expected: FAIL（`settings_page.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/features/settings/pages/settings_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(appConfigProvider);
    final ctrl = ref.read(appConfigProvider.notifier);
    final configured = cfg.llm.isConfigured;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _SectionHeader('数据源'),
          SwitchListTile(
            key: const Key('settings-ai-switch'),
            title: const Text('使用真实大模型（AI）'),
            subtitle: Text(
              configured
                  ? '关闭则使用离线 Mock 演示数据'
                  : '未配置 API Key，仅可使用 Mock（构建时 --dart-define=LLM_API_KEY=…）',
            ),
            value: cfg.dataSource == DataSource.ai,
            onChanged: configured
                ? (on) =>
                      ctrl.setDataSource(on ? DataSource.ai : DataSource.mock)
                : null,
          ),
          ListTile(
            title: const Text('当前模型'),
            subtitle: Text(configured ? cfg.llm.model : '—'),
          ),
          const Divider(),
          const _SectionHeader('演示'),
          SwitchListTile(
            key: const Key('settings-demo-switch'),
            title: const Text('演示模式'),
            subtitle: const Text('在推荐结果页展示本次 AI 调用的 prompt 与原始返回'),
            value: cfg.featureFlags.showAiTrace,
            onChanged: ctrl.setShowAiTrace,
          ),
          const Divider(),
          const _SectionHeader('隐私'),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('清除本地数据'),
            subtitle: const Text('收藏 / 历史 / 个人背景（仅本机）'),
            onTap: () => _confirmClear(context, ref),
          ),
          const Divider(),
          const _SectionHeader('关于'),
          ListTile(
            title: const Text('版本'),
            subtitle: Text(cfg.appVersion),
          ),
          const ListTile(
            title: Text('SchoNavi'),
            subtitle: Text('用自然语言找到适合你的导师（AIGC 选导师助手）'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除本地数据'),
        content: const Text('将清除本机的收藏、历史与个人背景，且不可恢复。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final favoriteRepo = ref.read(favoriteRepositoryProvider);
    for (final item in favoriteRepo.list()) {
      await favoriteRepo.remove(item.professorId);
    }
    await ref.read(historyRepositoryProvider).clear();
    await ref.read(localStoreProvider).remove('user_profile.v1'); // M3 背景（若有）
    messenger.showSnackBar(const SnackBar(content: Text('已清除本地数据')));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行页面测试，确认通过**

Run: `flutter test test/features/settings/settings_page_test.dart`
Expected: PASS（3 个）。

- [ ] **Step 5: 在 `lib/core/router/app_router.dart` 加 `/settings` 路由**

在 import 区加：
```dart
import '../../features/settings/pages/settings_page.dart';
```
在 `routes:` 列表收尾 `]` 之前追加：
```dart
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
```

- [ ] **Step 6: 在 `lib/features/home/pages/home_page.dart` 的 AppBar 加设置入口**

把：
```dart
      appBar: AppBar(title: const Text('SchoNavi')),
```
替换为：
```dart
      appBar: AppBar(
        title: const Text('SchoNavi'),
        actions: [
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
```
（`go_router` 的 `context.push` 已在该文件可用——文件顶部已 import `go_router`。）

- [ ] **Step 7: 验证并提交**

Run: `flutter analyze && flutter test test/features/settings/`
Expected: analyze 无 error；settings 测试全绿。
```bash
git add lib/features/settings/ lib/core/router/app_router.dart lib/features/home/pages/home_page.dart test/features/settings/settings_page_test.dart
git commit -m "feat: settings page + /settings route + home entry (M6)"
```

---

## Task E: 首启引导（Onboarding）+ Splash 重定向

**Files:**
- Create: `lib/features/onboarding/pages/onboarding_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `test/core/router/app_router_test.dart`（预置 `seen_onboarding`）
- Modify: `test/core/router/chat_route_test.dart`（同上）
- Modify: `test/app_e2e_test.dart`（同上）
- Test: `test/features/onboarding/onboarding_test.dart`
- Test: `test/core/router/splash_redirect_test.dart`

> 约定：首启标记键 `'seen_onboarding'`（`LocalStore.getBool/setBool`）。

- [ ] **Step 1: 实现 `lib/features/onboarding/pages/onboarding_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';

/// 首启引导：介绍"AI 选导师"卖点，点「开始使用」写 seen_onboarding 后进首页。
class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  static const String seenKey = 'seen_onboarding';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.school_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('SchoNavi · AI 选导师', style: textTheme.headlineSmall),
              const SizedBox(height: 12),
              const _Point(
                icon: Icons.chat_bubble_outline,
                text: '用自然语言描述兴趣与目标，大模型理解后推荐匹配导师',
              ),
              const _Point(
                icon: Icons.auto_awesome,
                text: '推荐理由、套磁邮件、多导师对比、背景匹配分析一键生成',
              ),
              const _Point(
                icon: Icons.verified_outlined,
                text: '事实接地于公开资料，不编造；可离线 Mock 演示',
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await ref
                        .read(localStoreProvider)
                        .setBool(seenKey, true);
                    if (context.mounted) context.go('/home');
                  },
                  child: const Text('开始使用'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 在 `lib/core/router/app_router.dart` 加 `/onboarding` 路由 + 首启重定向**

在 import 区加：
```dart
import '../../core/di/providers.dart';
import '../../features/onboarding/pages/onboarding_page.dart';
```
把 `GoRouter(` 的构造改为带 `redirect`（保留 `initialLocation: '/home'`），即在 `routes:` 之前插入：
```dart
    redirect: (context, state) {
      final seen =
          ref.read(localStoreProvider).getBool(OnboardingPage.seenKey) ?? false;
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!seen && !atOnboarding) return '/onboarding';
      if (seen && atOnboarding) return '/home';
      return null;
    },
```
在 `routes:` 列表收尾 `]` 之前追加：
```dart
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingPage(),
      ),
```

- [ ] **Step 3: 写失败测试 `test/features/onboarding/onboarding_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/onboarding/pages/onboarding_page.dart';

void main() {
  testWidgets('点「开始使用」写 seen_onboarding 并跳首页', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingPage(),
        ),
        GoRoute(path: '/home', builder: (_, _) => const Text('home-marker')),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();

    expect(find.text('home-marker'), findsOneWidget);
    expect(
      container.read(localStoreProvider).getBool(OnboardingPage.seenKey),
      isTrue,
    );
  });
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/features/onboarding/onboarding_test.dart`
Expected: PASS（1 个）。

- [ ] **Step 5: 写失败测试 `test/core/router/splash_redirect_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/router/app_router.dart';
import 'package:scho_navi/features/onboarding/pages/onboarding_page.dart';

Future<Widget> _app(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('未读引导 → 重定向到 /onboarding', (tester) async {
    await tester.pumpWidget(await _app(<String, Object>{}));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('已读引导 → 不显示引导（停在首页）', (tester) async {
    await tester.pumpWidget(
      await _app(<String, Object>{'seen_onboarding': true}),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsNothing);
  });
}
```

- [ ] **Step 6: 运行测试，确认通过**

Run: `flutter test test/core/router/splash_redirect_test.dart`
Expected: PASS（2 个）。

- [ ] **Step 7: 修既有 3 个测试——mock prefs 预置 `seen_onboarding:true`（否则被重定向到引导页）**

在以下三处把 `SharedPreferences.setMockInitialValues(<String, Object>{});` 改为
`SharedPreferences.setMockInitialValues(<String, Object>{'seen_onboarding': true});`：
- `test/core/router/app_router_test.dart`（`_wrap` 内）
- `test/core/router/chat_route_test.dart`（`main` 内）
- `test/app_e2e_test.dart`（`_wrap` 内）

- [ ] **Step 8: 运行受影响测试，确认通过**

Run: `flutter test test/core/router/app_router_test.dart test/core/router/chat_route_test.dart test/app_e2e_test.dart`
Expected: PASS（预置 `seen_onboarding:true` 后不再被重定向，原断言成立）。

- [ ] **Step 9: 提交**

```bash
git add lib/features/onboarding/ lib/core/router/app_router.dart test/features/onboarding/onboarding_test.dart test/core/router/splash_redirect_test.dart test/core/router/app_router_test.dart test/core/router/chat_route_test.dart test/app_e2e_test.dart
git commit -m "feat: onboarding page + first-launch redirect + fix existing tests (M6)"
```

---

## Task F: UI 打磨与文案（checklist，无单测）

**Files:**（按需）`lib/core/theme/app_theme.dart`、`lib/features/home/pages/home_page.dart`、`lib/shared/widgets/`（`loading_view.dart`/`empty_view.dart`/`error_view.dart`）、各 AI 入口页面、`android/app/src/main/res/`（图标/启动图）。

> 纯视觉/文案打磨无单测；以 `flutter analyze` 无 error + 既有测试全绿 + 人工冒烟为准。每改一处后跑 `flutter test` 确认不回归，再提交。

- [ ] **Step 1: 首页文案体现"真实大模型"**

把 `lib/features/home/pages/home_page.dart` 标题 `'用自然语言找到适合你的导师'` 下方补一行副标题（在该 `Text(...)` 之后插入）：
```dart
            const SizedBox(height: 4),
            Text(
              '由真实大模型理解你的需求并接地推荐，可一键追问 / 套磁 / 对比 / 匹配分析',
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
```
> ⚠️ `app_router_test`/`app_e2e_test` 断言 `find.text('用自然语言找到适合你的导师')`——保持该原标题文本不变（只新增副标题），勿改原句。

- [ ] **Step 2: 三态打磨复核（不改 API，只补文案/视觉）**

逐一检查并按需微调（保持既有测试断言文案不变；如需改文案则同步改对应测试）：
- 加载：`LoadingView` 在推荐/对比/匹配/套磁均带场景化 `label`（推荐页已有"正在为你匹配导师…"）。
- 空态：推荐空态"放宽条件"按钮已存在；收藏/历史空态文案保留（`还没有收藏导师`/`暂无搜索历史`——测试依赖，勿改）。
- 错误：统一走 `ErrorView(message, onRetry)`。

- [ ] **Step 3: 主题/色彩/圆角统一（`lib/core/theme/app_theme.dart`）**

确认靛蓝/青绿学术色 `ColorScheme.fromSeed` 种子色与圆角一致；如调整 seed/圆角，跑 `flutter test test/core/theme/app_theme_test.dart` 确认不回归。

- [ ] **Step 4: 应用名/图标/启动图**

- 应用名：`android/app/src/main/AndroidManifest.xml` 的 `android:label` 设为 `SchoNavi`（或中文名）。
- 图标/启动图：替换 `android/app/src/main/res/mipmap-*/` 与 `drawable*/launch_background.xml`（可用 `flutter_launcher_icons`，但**不新增依赖**则手工替换占位资源即可）。
- 不影响测试。

- [ ] **Step 5: 各 AI 入口视觉一致性**

确认「继续追问」「生成套磁邮件」(M3)、「匹配分析」(M5)、收藏页「对比」(M4) 图标与按钮风格一致（`auto_awesome`/`mail_outline`/`insights_outlined`/`compare_arrows`）。仅 M3/M4/M5 已落地者需对齐。

- [ ] **Step 6: 验证并提交**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全绿。
```bash
git add -A
git commit -m "polish: home copy + three-state + theme + app name/icon (M6)"
```

---

## Task G: APK 构建（checklist）

**Files:** `android/app/build.gradle(.kts)`（确认 `minSdk`）；无代码逻辑。

- [ ] **Step 1: 确认 `minSdk=31`**

打开 `android/app/build.gradle.kts`（或 `build.gradle`），确认/设置 `minSdk = 31`。

- [ ] **Step 2: 构建「真 AI 包」（带 key，现场联网演示）**

Run（替换真实 key）：
```bash
flutter build apk --release --dart-define=LLM_API_KEY=sk-你的key
```
Expected: 产物 `build/app/outputs/flutter-apk/app-release.apk`；安装后启动即 `ai`（首页设置可现场切回 mock）。

- [ ] **Step 3: 构建「离线演示包」（不带 key，mock 兜底）**

Run:
```bash
flutter build apk --release
```
Expected: 无 key → 启动即 `mock`；断网可演示（设置页 AI 开关因无 key 置灰）。

- [ ] **Step 4: 记录两种构建命令到作品说明（Task H 引用）**

无代码改动；把上述两条命令写入 `docs/作品说明.md` 的"构建与运行"小节（Task H）。

> 本任务无单测；以两个 APK 均能安装、按预期启动为准。

---

## Task H: 作品说明 / 答辩叙事（交付文档）

**Files:**
- Create: `docs/作品说明.md`

- [ ] **Step 1: 撰写 `docs/作品说明.md`**

按以下结构成文（据实际已落地里程碑勾选"大模型应用能力清单"——做了哪些写哪些）：

```markdown
# SchoNavi 作品说明

## 一、选题与痛点
升学 / 保研 / 申博 / 留学的"选导师"环节信息分散、匹配难。SchoNavi 用自然语言 +
大模型，把"理解需求 → 接地推荐 → 追问答疑 → 套磁 / 对比 / 匹配分析"串成闭环。

## 二、用户与价值（应用价值：可行性 / 前景）
- 目标用户：准备读研 / 读博 / 留学的学生。
- 价值：把分散信息整合为可执行决策；离线 Mock 兜底，演示零依赖网络亦可。

## 三、架构
- 三层：presentation（features）/ domain（entities+repositories）/ data（ai/mock/local）。
- AI 数据源：`DataSource.mock|ai|http`，DI 按 `AppConfig` 运行时切换（设置页可切）。
- 接地：导师事实取自 fixtures / 传入 `Professor`，模型只产出理由 / 文本 / 结构化结论。
- （架构图：三层 + AI 数据源 + 接地，建议补一张图置此处）

## 四、大模型应用能力清单
- 结构化输出：需求理解 + 推荐 JSON（M1）。
- 接地生成 / RAG-lite：候选检索接缝 `ProfessorCandidateSource` + 推荐理由接地（M1）。
- 多轮对话（M1）。
- SSE 流式（M2）。
- 多任务生成：套磁邮件（M3）/ 多导师对比（M4）/ 背景匹配分析（M5）。
- Provider 无关 `LlmClient` + Mock 兜底；AI 透明化（演示模式展示 prompt 与原始返回，M6）。

## 五、功能 → 评分维度对照
| 功能 | 创新性 | 应用价值 | 完成度 | 大模型应用能力 |
|---|---|---|---|---|
| 自然语言推荐 + 需求理解卡 | ✓ | ✓ | ✓ | 结构化输出 / 接地 |
| 继续追问（流式多轮） | ✓ | ✓ | ✓ | 多轮 + SSE |
| 套磁 / 对比 / 匹配分析 | ✓ | ✓ | ✓ | 多任务生成 |
| 运行时数据源切换 + AI 透明化 | ✓ | | ✓ | 可视化 + 兜底 |

## 六、构建与运行
- 真 AI 包：`flutter build apk --release --dart-define=LLM_API_KEY=sk-…`
- 离线演示包：`flutter build apk --release`
- 本地运行：`flutter run --dart-define=LLM_API_KEY=sk-…`（不带 key 即 mock）

## 七、演示脚本（3-5 分钟）
1. 首启引导 → 首页输入"医学影像 上海 硕士" → 真实大模型推荐 + 需求理解卡。
2. 打开设置「演示模式」→ 回推荐页「查看 AI 详情」展示 prompt 与原始返回（AI 透明化）。
3. 继续追问（流式）→ 套磁邮件 / 多导师对比 / 背景匹配分析（按已落地功能演示）。
4. 设置页切到 Mock → 断网仍可演示（兜底）。
（每步配截图）
```

- [ ] **Step 2: 提交**

```bash
git add docs/作品说明.md
git commit -m "docs: 作品说明（架构/能力清单/评分对照/演示脚本）(M6)"
```

---

## Task I: 收尾全量验证 + 人工冒烟

**Files:** 无（仅验证）

- [ ] **Step 1: 全量分析与测试**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全部 PASS——既有 + 本里程碑新增（config 控制器 5、llm_trace 4、ai_trace_panel 1、settings 3、onboarding 1、splash 2 = 16；另修正既有 3 个路由/e2e 测试）。

- [ ] **Step 2: 确认工作区干净**

Run: `git status --short`
Expected: 干净（除可能的 `.agents/` 等非本任务文件、图标资源）。

- [ ] **Step 3: 人工冒烟**

Run（真 AI 包动线，替换真实 key）：
```bash
flutter run --dart-define=LLM_API_KEY=sk-你的key
```
手动核对：
- 首次启动 → **引导页** → 「开始使用」→ 进首页；二次启动不再出引导。
- 首页右上 **设置** → 数据源 AI 开关（有 key 可切）、当前模型、**演示模式**开关、清除本地数据（确认弹窗 + 提示）、版本。
- 开**演示模式** → 推荐一次 → 推荐页底部「查看 AI 详情」可展开，显示 model、实际 prompt（含 system/user）、原始返回。
- 设置里切到 **Mock** → 仓储自动重建，推荐回到 mock 行为（无需重启）。
- 关 key 直接 `flutter run` → 启动即 mock；设置页 AI 开关置灰并提示未配置。
- `flutter build apk --release`（离线包）与带 key 包均能安装启动。

> 收口完成：四项评分均有可视抓手；演示按 `docs/作品说明.md` 动线进行。

---

## 自查（Self-Review）记录

- **Spec 覆盖**（M6 spec §2–§3）：
  - §2.1 运行时配置切换（`AppConfigController`/`NotifierProvider`/`setDataSource` 仅有 key 切 ai）→ Task A。
  - §2.2 AI 能力可视化（`LlmTrace`/最近一次调用快照/演示模式包裹/推荐页「查看 AI 详情」）→ Task B（核心）+ Task C（面板）。
  - §2.3 设置页（数据源 / 模型 / 演示模式 / 清除本地 / 关于；无 key 置灰）→ Task D。
  - §2.4 UI 打磨与补全（引导/Splash、三态、主题文案、应用名图标、AI 入口一致）→ Task E（引导/Splash）+ Task F（其余）。
  - §2.5 APK 构建（minSdk31、真 AI 包 / 离线演示包）→ Task G。
  - §2.6 作品说明（选题/架构/能力清单/评分对照/演示脚本）→ Task H。
  - §3 测试：`app_config_controller_test`(Task A)、`ai_trace_test`→`llm_trace_test`(Task B)、`settings_page_test`(Task D)、`onboarding_test`/`splash_redirect_test`(Task E) 全部落位。
  - §4 偏差（`Provider`→`NotifierProvider`、trace 仅演示模式、拆分实现、埋点低优先级不做）→ 已在头部与各 Task 记录。
- **占位扫描**：无 TBD/TODO；A-E 每个 code step 给出完整可编译代码 + 命令与期望；F-H 为明确 checklist + 具体命令/文档骨架（纯打磨/交付无单测，spec §3 已说明）。
- **类型一致性**：
  - `appConfigProvider`：`NotifierProvider<AppConfigController, AppConfig>`；`AppConfigController{setDataSource(DataSource), setShowAiTrace(bool), build()→watch(initialAppConfigProvider)}`；`AppConfig.copyWith(...)`、`FeatureFlags{showMatchScore, showAiTrace, copyWith}` 在 config(A)、settings(D)、面板(C) 一致。
  - `initialAppConfigProvider`（`Provider<AppConfig>`）在 config(A)、main(A)、各测试 override 一致；`appConfigProvider.overrideWithValue` 全部迁移到 `initialAppConfigProvider`（main + ai_providers_test 已改；M3/M4/M5 计划已留注）。
  - `LlmTrace{model, messages:List<LlmMessage>, rawResponse, elapsedMs}`、`TracingLlmClient{delegate, model, onTrace}`（实现 `complete`+`stream`）、`aiTraceProvider`(`NotifierProvider<AiTraceController, LlmTrace?>`)/`AiTraceController{record, clear}` 在 trace(B)、provider(B)、面板(C)、测试一致。
  - `OnboardingPage.seenKey == 'seen_onboarding'` 在页面(E)、路由 redirect(E)、各测试一致；redirect 用 `state.matchedLocation`（go_router 17）。
  - 复用既有 `localStoreProvider`/`LocalStore.getBool/setBool/remove`、`favoriteRepositoryProvider.list()/remove`、`historyRepositoryProvider.clear()`（settings 清除本地，D）。
- **不回归**：`appConfigProvider` 改 `NotifierProvider` 仅影响两处 override（A 一并改）；首启 redirect 影响 3 个既有测试（E Step7 预置 `seen_onboarding:true`）；首页副标题只新增、不改既有断言文本（F Step1 警示）；`_AiTracePanel` 非演示模式返回空白（C 不影响既有推荐页测试）；设置/对比等切换经 `ref.watch(appConfigProvider)` 自动重建，无需改各仓储。Task I 跑全量回归。
- **Widget 测试要点**：settings/ai_trace_panel 用 `ProviderScope.containerOf(tester.element(...))` 读状态、`Key('settings-ai-switch'/'settings-demo-switch')` 定位开关；splash_redirect 用真 `routerProvider` + `find.byType(OnboardingPage)` 验证重定向，避免依赖具体首页文案。
- **M3/M4/M5 解耦**：M6 不依赖其落地——设置「清除本地」用 `localStore.remove('user_profile.v1')` 兜底（键不存在亦安全）；作品说明"能力清单"按已落地里程碑勾选。
