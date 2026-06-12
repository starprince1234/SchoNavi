# SchoNavi Phase 2 · 完成度收尾（M6）Bento 皮肤 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把项目从"功能可用"抬到"评委一眼看懂 AI 在哪、好用、完整可交付"——运行时切数据源、AI 调用透明化（讲解模式）、设置页、可滑动首启引导、补齐 Phase 0 遗留的思源黑体字体、品牌启动图/应用名图标、双 APK 构建与作品说明文档。直接服务四项评分（界面/交互创新、作品完成度、大模型应用能力显式可视化）。

**Architecture:** `appConfigProvider` 由 `Provider<AppConfig>` 改 `NotifierProvider`（`AppConfigController`），初值经新 `initialAppConfigProvider` 注入，支持运行时在 `mock`/`ai` 间切换与开关演示模式；所有仓储 provider 已 `ref.watch(appConfigProvider)`，切换后自动重建。新增 `LlmTrace` + `TracingLlmClient` 装饰器（仅 `featureFlags.showAiTrace` 演示模式包裹 `DeepSeekLlmClient`，记录最近一次调用快照到 `aiTraceProvider`），推荐结果页加 Bento「查看 AI 详情」折叠区。新增 `features/settings/`（`/settings`）与 `features/onboarding/`（`/onboarding` 可滑动 `PageView` + 圆点 + 跳过；首启 `redirect`）。视觉全程沿用 Phase 0 已落地的 Bento 主题（`AppTheme`/`AppColors`/`SectionHeader`/`BentoTile`/品牌化三态），不再引入靛蓝/青绿（取代 M6 §2.4）。收尾补字体、启动图/图标、双 APK、作品说明。

**Tech Stack:** Flutter（Material 3，sdk ^3.12.1）；`flutter_riverpod ^3.3.1`（手写 provider，`Notifier`/`NotifierProvider`）；`go_router ^17.3.0`（`redirect`）；现有 `LlmClient.complete` + `stream`、`DeepSeekLlmClient`。**无新依赖**（启动图/图标手工替换 Android 资源，不引入 `flutter_native_splash`/`flutter_launcher_icons`）。

**Spec 依据:** `docs/superpowers/specs/2026-06-10-schonavi-bento-enhancement-design.md` §6（完成度收尾，并入 M6）、§9 Phase 2；细节设计沿用 `docs/superpowers/specs/2026-06-09-schonavi-m6-polish-narrative-design.md`，视觉以 Bento §3 为准。

---

## 前置状态（已核实，2026-06-10）

- **Phase 0（视觉&交互地基）功能已落地**：`AppTheme`(Bento ColorScheme/TextTheme/组件主题)、`AppColors`(墨/奶油/珊瑚/柠檬/绿 tokens)、`core/haptics/`、`core/motion/`(`sharedAxisPage`)、`shared/widgets`(`BentoTile`/`StatTile`/`SectionHeader`/`skeleton`/品牌化 `LoadingView`/`ErrorView`/`EmptyView`)。（Phase 0 plan 复选框未回填，但 commit `3ce86b9` 在，代码齐备。）
- **Phase 1（旗舰① 匹配雷达）功能已落地**：`MatchDimension`、`shared/widgets/radar_chart.dart`、匹配页、`Ai/MockMatchAnalysisRepository`。（commit `d420e19`。）
- **M1–M5 全部已落地**：推荐/需求理解/详情/流式追问/套磁邮件/对比/匹配分析/收藏/历史（`features/` 与实体齐备）。
- **基线绿**：`flutter analyze` → No issues；`flutter test` → All tests passed（209 个）。
- **`minSdk = 31`** 已在 `android/app/build.gradle.kts:22` 设好。

### Phase 0 遗留的真实缺口（本计划 Task F 补）

`lib/core/theme/app_theme.dart` 设了 `fontFamily: 'SourceHanSans'`，但 `pubspec.yaml` **未注册任何字体**、`assets/` 目录**不存在**。当前 Bento「编辑感签名」全程跑在系统回退字体上——这是完成度/界面惊艳度的最大单点缺口。Phase 0 plan Task 1 原计划打包思源黑体（Noto Sans SC）Medium+Black，因二进制字体未取得而延期。本计划 Task F 补齐。

---

## 已知破坏性改动（务必先读）

1. **`appConfigProvider` 由 `Provider<AppConfig>` 改 `NotifierProvider`。** 受影响的 `appConfigProvider.overrideWithValue(...)` 调用共 **5 处**（Task A 一并迁移到 `initialAppConfigProvider`）：
   - `lib/main.dart:26`
   - `test/core/di/ai_providers_test.dart:13`
   - `test/core/di/comparison_repository_provider_test.dart:22`
   - `test/core/di/match_analysis_repository_provider_test.dart:22`
   - `test/core/di/outreach_email_provider_test.dart:17`
   > （`providers_test.dart`/`chat_repository_provider_test.dart` 不 override appConfig，走默认 mock，不受影响。）
2. **首启 `redirect` 影响 4 个既有测试**（Task E 一并预置 `seenOnboarding:true`）：
   - `test/app_e2e_test.dart:9`
   - `test/core/router/app_router_test.dart:9`
   - `test/core/router/chat_route_test.dart:10`
   - `test/widget_test.dart:8`
3. 首页 AppBar 新增设置入口、推荐页新增 `_AiTracePanel`（非演示模式返回空白）均为**加性**，不改既有断言文本。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `lib/core/config/app_config.dart` | **改**：`FeatureFlags.showAiTrace`+`copyWith`；`AppConfig.copyWith`；`initialAppConfigProvider`；`AppConfigController`+`appConfigProvider`(NotifierProvider) |
| `lib/main.dart` | **改**：override `initialAppConfigProvider` |
| `test/core/config/app_config_controller_test.dart` | 新：切 ai 仅有 key 允许 / 切换生效 / demo 开关 |
| `test/core/di/{ai_providers,comparison_repository_provider,match_analysis_repository_provider,outreach_email_provider}_test.dart` | **改**：override 迁移到 `initialAppConfigProvider` |
| `lib/core/ai/llm_trace.dart` | 新：`LlmTrace` + `TracingLlmClient` + `AiTraceController`/`aiTraceProvider` |
| `lib/core/di/providers.dart` | **改**：`llmClientProvider` 演示模式包裹 `TracingLlmClient` |
| `test/core/ai/llm_trace_test.dart` | 新：记录 model/messages/raw；失败不记录；provider 包裹切换 |
| `lib/features/recommendation/pages/recommendation_page.dart` | **改**：底部 Bento「查看 AI 详情」折叠区（仅演示模式） |
| `test/features/recommendation/ai_trace_panel_test.dart` | 新：演示模式 + 有 trace → 面板可展开显示 model |
| `lib/features/settings/pages/settings_page.dart` | 新：数据源/模型/演示模式/清除本地/关于（Bento，复用 `SectionHeader`） |
| `lib/core/router/app_router.dart` | **改**：`/settings`、`/onboarding` 路由 + 首启 `redirect` |
| `lib/features/home/pages/home_page.dart` | **改**：AppBar 加设置入口；副标题体现"真实大模型"（Task H） |
| `test/features/settings/settings_page_test.dart` | 新：数据源切换 / 无 key 置灰 / demo 开关 |
| `lib/features/onboarding/pages/onboarding_page.dart` | 新：可滑动 `PageView`+圆点+跳过，写 `seenOnboarding` |
| `test/features/onboarding/onboarding_test.dart` | 新：跳过 / 滑到末页「开始使用」均写标记并跳首页 |
| `test/core/router/splash_redirect_test.dart` | 新：未读引导→/onboarding；已读→/home |
| `test/{app_e2e,core/router/app_router,core/router/chat_route,widget}_test.dart` | **改**：mock prefs 预置 `seenOnboarding:true` |
| `pubspec.yaml` + `assets/fonts/` | **改/新**：注册并打包思源黑体（Noto Sans SC）Medium+Black |
| `android/app/src/main/{AndroidManifest.xml,res/...}` | **改**：应用名/图标/启动背景品牌化 |
| `docs/作品说明.md` | 新：选题/架构/大模型能力清单/评分对照/演示脚本 |

---

## Task A: 运行时配置（appConfigProvider → NotifierProvider）

**Files:**
- Modify: `lib/core/config/app_config.dart`
- Modify: `lib/main.dart`
- Modify: `test/core/di/ai_providers_test.dart`, `test/core/di/comparison_repository_provider_test.dart`, `test/core/di/match_analysis_repository_provider_test.dart`, `test/core/di/outreach_email_provider_test.dart`
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

  /// 切数据源；切 ai 仅在已配置 key 时允许（否则忽略，保持原值）。
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
Expected: PASS（控制器 5 个 + 既有 `app_config_test` 2 个；`AppConfig.resolve` 语义未改，旧测试仍绿）。

- [ ] **Step 5: 改 `lib/main.dart`——override `initialAppConfigProvider`**

把 `lib/main.dart:26` 的：
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
（其余不变。`appConfigProvider` 现为 `NotifierProvider`，初值经 `initialAppConfigProvider` 注入。）

- [ ] **Step 6: 迁移 4 个 provider 测试的 override**

在以下 4 个文件中，把 `appConfigProvider.overrideWithValue(` 改为 `initialAppConfigProvider.overrideWithValue(`（**仅改 provider 名，实参不变**；这些文件已 import `app_config.dart`，符号可用）：
- `test/core/di/ai_providers_test.dart`（约第 13 行）
- `test/core/di/comparison_repository_provider_test.dart`（约第 22 行）
- `test/core/di/match_analysis_repository_provider_test.dart`（约第 22 行）
- `test/core/di/outreach_email_provider_test.dart`（约第 17 行）

- [ ] **Step 7: 验证并提交**

Run: `flutter analyze && flutter test test/core/ test/core/di/`
Expected: analyze 无 error；全绿（NotifierProvider 改造不破坏既有 DI/config/路由测试——首启重定向相关留待 Task E）。
```bash
git add lib/core/config/app_config.dart lib/main.dart test/core/config/app_config_controller_test.dart test/core/di/ai_providers_test.dart test/core/di/comparison_repository_provider_test.dart test/core/di/match_analysis_repository_provider_test.dart test/core/di/outreach_email_provider_test.dart
git commit -m "feat: runtime AppConfigController (NotifierProvider) + demo flag (Phase 2)"
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

> 注：`ServerException` 文案在 `core/error/app_exception.dart`，无参构造（既有 `ai_providers_test` 等已这样用）。若该异常名不同，运行 Step 2 会暴露，替换为实际的 sealed 子类即可。

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/core/ai/llm_trace_test.dart`
Expected: FAIL（`llm_trace.dart`/演示模式包裹 不存在）。

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

在 import 区（与其它 `../ai/...` import 同处）追加：
```dart
import '../ai/llm_trace.dart';
```
把既有 `llmClientProvider`（`lib/core/di/providers.dart:44-52`）整体替换为：
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

- [ ] **Step 5: 运行测试，确认通过**

Run: `flutter test test/core/ai/llm_trace_test.dart`
Expected: PASS（4 个）。

- [ ] **Step 6: 提交**

```bash
git add lib/core/ai/llm_trace.dart lib/core/di/providers.dart test/core/ai/llm_trace_test.dart
git commit -m "feat: LlmTrace + TracingLlmClient + aiTraceProvider (demo-only) (Phase 2)"
```

---

## Task C: 推荐结果页 Bento「查看 AI 详情」折叠区

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
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/repositories/recommendation_repository.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/recommendation/pages/recommendation_page.dart';

class _FakeRecRepo implements RecommendationRepository {
  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    String? sessionId,
  }) async => const Success(
    RecommendationResult(
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

Widget _wrap() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const RecommendationPage(prompt: '医学影像'),
      ),
      GoRoute(path: '/professor/:id', builder: (_, _) => const Placeholder()),
      GoRoute(path: '/chat', builder: (_, _) => const Placeholder()),
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
    await tester.pumpWidget(_wrap());
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

> 该 fake 的字段（`Recommendation`/`RecommendationResult`/`QueryUnderstanding` 构造参数）沿用既有 `recommendation_page_test.dart` 的用法；若编译报字段名不符，对照既有测试微调即可。

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/features/recommendation/ai_trace_panel_test.dart`
Expected: FAIL（推荐页还没有「查看 AI 详情」）。

- [ ] **Step 3: 改 `lib/features/recommendation/pages/recommendation_page.dart`**

在 import 区追加（与既有相对 import 同处）：
```dart
import '../../../core/ai/llm_trace.dart';
import '../../../core/config/app_config.dart';
```
在 `data:` 分支的 `ListView(... children: [...])` 中，把 `...result.recommendations.map((r) { ... }),`（当前 `lib/features/recommendation/pages/recommendation_page.dart:68-82`）**之后**、`ListView` 的收尾 `],`（当前第 83 行）**之前**插入一行：
```dart
              const _AiTracePanel(),
```
然后在文件末尾（`_RecommendationPageState` 类闭合 `}` 之外）追加：
```dart
/// 仅演示模式（showAiTrace）且已有最近调用快照时显示，体现"AI 透明化"。
/// 视觉沿用 Bento 主题：Card(16 圆角 + 描边) + ExpansionTile，珊瑚 leading。
class _AiTracePanel extends ConsumerWidget {
  const _AiTracePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTrace = ref.watch(
      appConfigProvider.select((c) => c.featureFlags.showAiTrace),
    );
    final trace = ref.watch(aiTraceProvider);
    if (!showTrace || trace == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: ExpansionTile(
          leading: Icon(Icons.science_outlined, color: scheme.secondary),
          title: Text('查看 AI 详情', style: textTheme.titleMedium),
          subtitle: Text(
            '本次大模型调用快照（演示模式）',
            style: textTheme.bodySmall,
          ),
          shape: const Border(),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '模型：${trace.model}（${trace.elapsedMs} ms）',
                style: textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('实际 prompt', style: textTheme.labelLarge),
            ),
            for (final m in trace.messages)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: SelectableText('[${m.role}] ${m.content}'),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('原始返回', style: textTheme.labelLarge),
            ),
            SelectableText(trace.rawResponse),
          ],
        ),
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
git commit -m "feat: Bento AI trace panel on recommendation page (demo-only) (Phase 2)"
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

  testWidgets('有 key 时切 AI 开关 → 在 ai/mock 间切换', (tester) async {
    await tester.pumpWidget(await _wrap(AppConfig.resolve(apiKey: 'sk-test')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    // resolve 有 key 初值即 ai，先关到 mock 再开，验证开关生效
    await tester.tap(find.byKey(const Key('settings-ai-switch')));
    await tester.pumpAndSettle();
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

> 复用 Phase 0 的共享 `SectionHeader`（不自造）。清除本地数据仅用既有 API：收藏 `list()`+`remove()`、历史 `clear()`、背景 `localStore.remove(LocalProfileRepository.storageKey)`（引入 data 层仅为读一个 const key，无行为耦合）。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../data/local/local_profile_repository.dart'
    show LocalProfileRepository;
import '../../../shared/widgets/section_header.dart';

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
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SectionHeader('数据源'),
          ),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SectionHeader('演示'),
          ),
          SwitchListTile(
            key: const Key('settings-demo-switch'),
            title: const Text('演示模式'),
            subtitle: const Text('在推荐结果页展示本次 AI 调用的 prompt 与原始返回'),
            value: cfg.featureFlags.showAiTrace,
            onChanged: ctrl.setShowAiTrace,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SectionHeader('隐私'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('清除本地数据'),
            subtitle: const Text('收藏 / 历史 / 个人背景（仅本机）'),
            onTap: () => _confirmClear(context, ref),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SectionHeader('关于'),
          ),
          ListTile(title: const Text('版本'), subtitle: Text(cfg.appVersion)),
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
    await ref.read(localStoreProvider).remove(LocalProfileRepository.storageKey);
    messenger.showSnackBar(const SnackBar(content: Text('已清除本地数据')));
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
在最外层 `routes:` 列表收尾 `]`（当前 `lib/core/router/app_router.dart:97` 的 `],` 之前）追加：
```dart
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
```

- [ ] **Step 6: 在 `lib/features/home/pages/home_page.dart` 的 AppBar 加设置入口**

把 `lib/features/home/pages/home_page.dart:72` 的：
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
（`home_page.dart` 顶部已 import `go_router`，`context.push` 可用。`home_page_test.dart` 自带路由无 `/settings`，但不点击设置按钮，故不回归。）

- [ ] **Step 7: 验证并提交**

Run: `flutter analyze && flutter test test/features/settings/ test/features/home/`
Expected: analyze 无 error；settings + home 测试全绿。
```bash
git add lib/features/settings/ lib/core/router/app_router.dart lib/features/home/pages/home_page.dart test/features/settings/settings_page_test.dart
git commit -m "feat: Bento settings page + /settings route + home entry (Phase 2)"
```

---

## Task E: 可滑动首启引导（Onboarding）+ 首启重定向

**Files:**
- Create: `lib/features/onboarding/pages/onboarding_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `test/core/router/app_router_test.dart`, `test/core/router/chat_route_test.dart`, `test/app_e2e_test.dart`, `test/widget_test.dart`（预置 `seenOnboarding`）
- Test: `test/features/onboarding/onboarding_test.dart`, `test/core/router/splash_redirect_test.dart`

> 约定：首启标记键 `'seenOnboarding'`（与 Bento spec §6 及既有 `shared_preferences_local_store_test` 用例一致），存取经 `LocalStore.getBool/setBool`。

- [ ] **Step 1: 实现 `lib/features/onboarding/pages/onboarding_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';

/// 首启引导：可滑动 PageView 介绍"AI 选导师"卖点 + 圆点指示 + 跳过；
/// 末页「开始使用」或随时「跳过」→ 写 seenOnboarding 后进首页。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  static const String seenKey = 'seenOnboarding';

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingData {
  const _OnboardingData(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

const _pages = <_OnboardingData>[
  _OnboardingData(
    Icons.chat_bubble_outline,
    '自然语言找导师',
    '用一句话描述你的研究兴趣与目标，大模型理解后接地推荐匹配的导师。',
  ),
  _OnboardingData(
    Icons.auto_awesome,
    '一站式申请助手',
    '推荐理由、追问答疑、套磁邮件、多导师对比、背景匹配雷达——一键生成。',
  ),
  _OnboardingData(
    Icons.verified_outlined,
    '真实可信',
    '事实接地于公开资料、不编造；离线 Mock 兜底，断网也能演示。',
  ),
];

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(localStoreProvider).setBool(OnboardingPage.seenKey, true);
    if (mounted) context.go('/home');
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('跳过'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(p.icon, size: 72, color: scheme.secondary),
                        const SizedBox(height: 24),
                        Text(p.title, style: textTheme.displaySmall),
                        const SizedBox(height: 12),
                        Text(p.body, style: textTheme.bodyLarge),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? scheme.secondary : scheme.outline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_isLast ? '开始使用' : '下一步'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 在 `lib/core/router/app_router.dart` 加 `/onboarding` 路由 + 首启重定向**

在 import 区加：
```dart
import '../di/providers.dart';
import '../../features/onboarding/pages/onboarding_page.dart';
```
在 `GoRouter(` 构造里、`initialLocation: '/home',` 之后、`routes:` 之前插入 `redirect`：
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
在最外层 `routes:` 列表收尾 `]` 之前追加：
```dart
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
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

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _app(ProviderContainer container) {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(path: '/home', builder: (_, _) => const Text('home-marker')),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('点「跳过」写 seenOnboarding 并跳首页', (tester) async {
    final container = await _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();

    expect(find.text('home-marker'), findsOneWidget);
    expect(
      container.read(localStoreProvider).getBool(OnboardingPage.seenKey),
      isTrue,
    );
  });

  testWidgets('滑到末页「开始使用」写标记并跳首页', (tester) async {
    final container = await _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('下一步'), findsOneWidget);
    // 拖到末页（3 页 → 拖 2 次）
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('开始使用'), findsOneWidget);
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
Expected: PASS（2 个）。

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
      await _app(<String, Object>{'seenOnboarding': true}),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsNothing);
  });
}
```

- [ ] **Step 6: 运行测试，确认通过**

Run: `flutter test test/core/router/splash_redirect_test.dart`
Expected: PASS（2 个）。

- [ ] **Step 7: 修既有 4 个测试——mock prefs 预置 `seenOnboarding:true`**

在以下 4 处把 `SharedPreferences.setMockInitialValues(<String, Object>{});` 改为
`SharedPreferences.setMockInitialValues(<String, Object>{'seenOnboarding': true});`（否则被重定向到引导页，原断言失效）：
- `test/core/router/app_router_test.dart`（`main` 内，约第 9 行）
- `test/core/router/chat_route_test.dart`（`main` 内，约第 10 行）
- `test/app_e2e_test.dart`（`_wrap` 内，约第 9 行）
- `test/widget_test.dart`（`_wrap` 内，约第 8 行）

- [ ] **Step 8: 运行受影响测试，确认通过**

Run: `flutter test test/core/router/ test/app_e2e_test.dart test/widget_test.dart`
Expected: PASS（预置 `seenOnboarding:true` 后不再被重定向，原断言成立 + 新增 splash_redirect 2 个）。

- [ ] **Step 9: 提交**

```bash
git add lib/features/onboarding/ lib/core/router/app_router.dart test/features/onboarding/ test/core/router/splash_redirect_test.dart test/core/router/app_router_test.dart test/core/router/chat_route_test.dart test/app_e2e_test.dart test/widget_test.dart
git commit -m "feat: swipeable onboarding + first-launch redirect (Phase 2)"
```

---

## Task F: 打包思源黑体（补 Phase 0 遗留）

**Files:**
- Create: `assets/fonts/NotoSansSC-Medium.ttf`, `assets/fonts/NotoSansSC-Black.ttf`
- Modify: `pubspec.yaml`

> 主题已设 `fontFamily: 'SourceHanSans'`（`app_theme.dart:120`），但字体未打包。补齐后 Bento 黑体签名即生效。无字体二进制时 App 不崩溃（自动回退系统字体），故本任务可与其它任务解耦。

- [ ] **Step 1: 取字体二进制放入 `assets/fonts/`**

下载 **Noto Sans SC（= 思源黑体）** 两个静态字重，**仅取 Medium(500) 与 Black(900)** 控制体积：
- 来源 A：https://fonts.google.com/noto/specimen/Noto+Sans+SC → "Get font" → 解压取静态实例 `NotoSansSC-Medium.ttf`、`NotoSansSC-Black.ttf`。
- 来源 B：https://github.com/notofonts/noto-cjk （Sans）→ 取 Medium/Black。
- 放至 `assets/fonts/NotoSansSC-Medium.ttf`、`assets/fonts/NotoSansSC-Black.ttf`。

> 若执行者拿不到二进制：跳过 Step 1，仅做 Step 2 的 pubspec 注册会因找不到 asset 而 `flutter pub get`/`analyze` 报错——此时**先不要注册 fonts**，把本任务标记为"待补字体"，继续后续任务（系统回退字体下功能/测试不受影响），在交付前补上。

- [ ] **Step 2: 在 `pubspec.yaml` 注册字体与 assets**

在 `flutter:` 段（`uses-material-design: true` 之后）加入（注意 YAML 缩进为 2 空格）：
```yaml
  assets:
    - assets/fonts/

  fonts:
    - family: SourceHanSans
      fonts:
        - asset: assets/fonts/NotoSansSC-Medium.ttf
          weight: 500
        - asset: assets/fonts/NotoSansSC-Black.ttf
          weight: 900
```

- [ ] **Step 3: 拉取依赖、验证、提交**

Run: `flutter pub get && flutter analyze && flutter test`
Expected: `No issues found!`；全绿（字体加载不影响逻辑测试；widget 测试在测试环境用 Ahem 字体，断言不受影响）。
```bash
git add pubspec.yaml assets/fonts/
git commit -m "chore: bundle Source Han Sans (Noto Sans SC) Medium+Black (Phase 2, fixes Phase 0 gap)"
```

---

## Task G: 应用名 / 图标 / 启动背景品牌化（无新依赖）

**Files:** `android/app/src/main/AndroidManifest.xml`、`android/app/src/main/res/drawable*/launch_background.xml`、`android/app/src/main/res/mipmap-*/`、`android/app/src/main/res/values/colors.xml`（新建按需）。

> 手工替换 Android 资源，不引入 `flutter_native_splash`/`flutter_launcher_icons`。无单测；以构建安装后视觉为准。

- [ ] **Step 1: 应用名**

`android/app/src/main/AndroidManifest.xml` 的 `<application android:label="...">` 设为 `SchoNavi`。

- [ ] **Step 2: 启动背景品牌图（Bento）**

编辑 `android/app/src/main/res/drawable/launch_background.xml` 与 `drawable-v21/launch_background.xml`：把窗口背景设为 Bento 奶油底 `#FBF8F1`，中心放品牌图（占位用文字 logo 或简单图形 drawable 即可）。例如：
```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/launch_paper" />
    <item>
        <bitmap android:gravity="center" android:src="@mipmap/ic_launcher" />
    </item>
</layer-list>
```
在 `android/app/src/main/res/values/colors.xml`（无则新建）加：
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="launch_paper">#FBF8F1</color>
</resources>
```

- [ ] **Step 3: 应用图标**

用 Bento 风格图标替换 `android/app/src/main/res/mipmap-*/ic_launcher.png`（各 dpi）。无设计稿时保留默认图标，仅记录"待补图标"，不阻塞。

- [ ] **Step 4: 验证**

Run: `flutter build apk --debug`
Expected: 构建成功（资源合法）。无单测。
```bash
git add android/app/src/main/
git commit -m "chore: Bento app name + launch background + icon placeholders (Phase 2)"
```

---

## Task H: UI 文案打磨（checklist，保持既有断言文本）

**Files:** `lib/features/home/pages/home_page.dart`、（按需）各 AI 入口页面。

> 纯文案/视觉；以 `flutter analyze` 无 error + 既有测试全绿为准。**勿改既有测试依赖的文本**（`'用自然语言找到适合你的导师'`、`'开始推荐'`、`'还没有收藏导师'`、`'暂无搜索历史'` 等）。

- [ ] **Step 1: 首页副标题体现"真实大模型"**

在 `lib/features/home/pages/home_page.dart` 的标题 `Text('用自然语言找到适合你的导师', style: textTheme.titleLarge),`（当前第 78 行）**之后**插入：
```dart
            const SizedBox(height: 6),
            Text(
              '由真实大模型理解你的需求并接地推荐，可一键追问 / 套磁 / 对比 / 匹配分析',
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
```
（只新增副标题，原标题文本不变 → 不破坏 `app_e2e_test`/`widget_test` 的 `find.text('用自然语言找到适合你的导师')`。）

- [ ] **Step 2: AI 入口视觉一致性复核（按需，无强制改动）**

确认各 AI 入口图标风格统一（`auto_awesome` 追问 / `mail_outline` 套磁 / `insights_outlined` 匹配 / `compare_arrows` 对比）；如已一致则跳过。

- [ ] **Step 3: 验证并提交**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全绿。
```bash
git add lib/features/home/pages/home_page.dart
git commit -m "polish: home subtitle highlighting real LLM (Phase 2)"
```

---

## Task I: 双 APK 构建（checklist）

**Files:** 无代码改动（`minSdk = 31` 已在 `android/app/build.gradle.kts:22`）。

- [ ] **Step 1: 真 AI 包（带 key，现场联网演示）**

Run（替换真实 key）：
```bash
flutter build apk --release --dart-define=LLM_API_KEY=sk-你的key
```
Expected: 产物 `build/app/outputs/flutter-apk/app-release.apk`；安装后启动即 `ai`，设置页可现场切回 mock。

- [ ] **Step 2: 离线演示包（不带 key，mock 兜底）**

Run:
```bash
flutter build apk --release
```
Expected: 无 key → 启动即 `mock`；断网可演示（设置页 AI 开关因无 key 置灰）。

> 两条命令写入 `docs/作品说明.md`（Task J）。无单测；以两包均能安装并按预期启动为准。

---

## Task J: 作品说明 / 答辩叙事（交付文档）

**Files:**
- Create: `docs/作品说明.md`

- [ ] **Step 1: 撰写 `docs/作品说明.md`**

```markdown
# SchoNavi 作品说明

## 一、选题与痛点
升学 / 保研 / 申博 / 留学的"选导师"环节信息分散、匹配难。SchoNavi 用自然语言 +
大模型，把"理解需求 → 接地推荐 → 追问答疑 → 套磁 / 对比 / 匹配雷达 → 申请行动"串成闭环。

## 二、用户与价值（应用价值：可行性 / 前景）
- 目标用户：准备读研 / 读博 / 留学的学生。
- 价值：把分散信息整合为可执行决策；离线 Mock 兜底，演示零依赖网络亦可。

## 三、架构
- 三层：presentation（features）/ domain（entities+repositories）/ data（ai/mock/local），横切 core。
- AI 数据源：`DataSource.mock|ai|http`，DI 按 `AppConfig` 运行时切换（设置页可切，无需重启）。
- 接地：导师事实取自 fixtures / 传入 `Professor`，模型只产出理由 / 文本 / 结构化结论。
- 视觉：Bento 编辑识别系统（墨 + 奶油 + 珊瑚，柠檬黄仅大数字；思源黑体 Black/Medium）。
- （建议补一张架构图：三层 + AI 数据源 + 接地）

## 四、大模型应用能力清单
- 结构化输出：需求理解 + 推荐 JSON（M1）。
- 接地生成 / RAG-lite：候选检索接缝 `ProfessorCandidateSource` + 推荐理由接地（M1）。
- 多轮对话（M1）。
- SSE 流式（M2）。
- 多任务生成：套磁邮件（M3）/ 多导师对比（M4）/ 背景匹配分析 + 5 轴契合雷达（M5 + Phase 1）。
- Provider 无关 `LlmClient` + Mock 兜底；AI 透明化（讲解模式展示 prompt 与原始返回，Phase 2）。

## 五、功能 → 评分维度对照
| 功能 | 创新性 | 应用价值 | 完成度 | 大模型应用能力 |
|---|---|---|---|---|
| 自然语言推荐 + 需求理解卡 | ✓ | ✓ | ✓ | 结构化输出 / 接地 |
| 继续追问（流式多轮） | ✓ | ✓ | ✓ | 多轮 + SSE |
| 套磁 / 对比 / 匹配雷达 | ✓ | ✓ | ✓ | 多任务生成 |
| Bento 视觉 + 移动手势交互 | ✓ |  | ✓ |  |
| 运行时数据源切换 + AI 透明化 | ✓ |  | ✓ | 可视化 + 兜底 |

## 六、构建与运行
- 真 AI 包：`flutter build apk --release --dart-define=LLM_API_KEY=sk-…`
- 离线演示包：`flutter build apk --release`
- 本地运行：`flutter run --dart-define=LLM_API_KEY=sk-…`（不带 key 即 mock）

## 七、演示脚本（≈90s）
1. 首启引导（swipe）→ Bento 首页 → 输入"医学影像 上海 硕士"→ 真实大模型推荐 + 需求理解卡。
2. 点导师（Hero 转场）→ 匹配雷达描边生长 + 综合契合大数字滚动 → 点某维度看 AI 解读。
3. 打开设置「演示模式」→ 回推荐页「查看 AI 详情」展示 prompt 与原始返回（AI 透明化）。
4. 继续追问（流式）→ 套磁邮件 / 多导师对比（按需）。
5. 设置页切到 Mock → 断网仍可演示（兜底）。
（每步配截图）
```

- [ ] **Step 2: 提交**

```bash
git add docs/作品说明.md
git commit -m "docs: 作品说明（架构/能力清单/评分对照/演示脚本）(Phase 2)"
```

---

## Task K: 收尾全量验证 + 人工冒烟

**Files:** 无（仅验证）

- [ ] **Step 1: 全量分析与测试**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全部 PASS——既有 209 + 本阶段新增（config 控制器 5、llm_trace 4、ai_trace_panel 1、settings 3、onboarding 2、splash 2 = 17），修正的 4 个路由/e2e/widget 测试仍绿。

- [ ] **Step 2: 确认工作区干净**

Run: `git status --short`
Expected: 干净（除字体/图标等二进制资源已提交）。

- [ ] **Step 3: 人工冒烟（替换真实 key）**

```bash
flutter run --dart-define=LLM_API_KEY=sk-你的key
```
手动核对：
- 首次启动 → **可滑动引导**（3 页 + 圆点 + 跳过）→ 「开始使用」/「跳过」进首页；二次启动不再出引导。
- 首页右上 **设置** → AI 开关（有 key 可切）、当前模型、**演示模式**开关、清除本地数据（确认弹窗 + 提示）、版本。
- 开**演示模式** → 推荐一次 → 推荐页底部 Bento「查看 AI 详情」可展开，显示 model、实际 prompt（system/user）、原始返回。
- 设置里切到 **Mock** → 仓储自动重建，推荐回到 mock 行为（无需重启）。
- 不带 key `flutter run` → 启动即 mock；设置页 AI 开关置灰并提示未配置。
- 字体已生效（标题为思源黑体 Black 粗黑）；`flutter build apk --release`（离线包）与带 key 包均能安装启动。

> 收口完成：四项评分均有可视抓手；演示按 `docs/作品说明.md` 动线进行。Phase 2（必交）达成；可继续 Phase 3（申请军师·Target）。

---

## 自查（Self-Review）记录

- **Spec 覆盖**（Bento §6 + M6 §2–§3）：
  - 运行时配置（`AppConfigController`/`NotifierProvider`/`initialAppConfigProvider`/切 ai 仅有 key）→ Task A。
  - 讲解模式 / AI 透明化（`LlmTrace`/`TracingLlmClient`/`aiTraceProvider`/推荐页「查看 AI 详情」）→ Task B + C。
  - 设置页（数据源 / 模型 / 演示模式 / 清除本地 / 关于；无 key 置灰；Bento `SectionHeader`）→ Task D。
  - 引导/Splash（可滑动 `PageView`+圆点+跳过；首启 `seenOnboarding` 重定向；启动背景品牌图）→ Task E + Task G。
  - 三态打磨（骨架屏 + 品牌化空/错态）→ **Phase 0 已落地**（`LoadingView`/`ErrorView`/`EmptyView`/`skeleton` 已品牌化），本阶段不重复，仅 Task H 复核文案。
  - 字体（思源黑体 Black+Medium）→ Task F（补 Phase 0 遗留）。
  - APK（minSdk31 已设、真 AI 包 / 离线包）→ Task I。
  - 作品说明（选题/架构/能力清单/评分对照/演示脚本）→ Task J。
  - 测试：`app_config_controller_test`(A)、`llm_trace_test`(B)、`ai_trace_panel_test`(C)、`settings_page_test`(D)、`onboarding_test`+`splash_redirect_test`(E) 全部落位。
- **占位扫描**：无 TBD/TODO；A–E 每个 code step 给出完整可编译代码 + 命令与期望；F–K 为明确 checklist + 具体命令/文档骨架（纯打磨/交付/二进制资源无单测）。
- **类型一致性**：
  - `appConfigProvider`：`NotifierProvider<AppConfigController, AppConfig>`；`AppConfigController{setDataSource(DataSource), setShowAiTrace(bool), build()→watch(initialAppConfigProvider)}`；`AppConfig.copyWith`、`FeatureFlags{showMatchScore, showAiTrace, copyWith}` 在 A/C/D 一致。`showMatchScore` 保留（Phase 1 雷达/匹配用）。
  - `initialAppConfigProvider`(`Provider<AppConfig>`) 在 A、main、所有 override 一致；`appConfigProvider.overrideWithValue` **5 处**全部迁移（main + 4 provider 测试）。
  - `LlmTrace{model, messages:List<LlmMessage>, rawResponse, elapsedMs}`、`TracingLlmClient{delegate, model, onTrace}`（实现 `complete`+`stream`，匹配 `llm_client.dart` 实际签名）、`aiTraceProvider`(`NotifierProvider<AiTraceController, LlmTrace?>`)/`AiTraceController{record, clear}` 在 B/C/测试一致。
  - `OnboardingPage.seenKey == 'seenOnboarding'` 在页面(E)、router redirect(E)、各测试一致；redirect 用 `state.matchedLocation`（go_router 17）。
  - 复用既有 API（无接口改动、零 fake 破坏）：`favoriteRepositoryProvider.list()/remove`、`historyRepositoryProvider.clear()`、`localStoreProvider.remove(LocalProfileRepository.storageKey)`、`localStoreProvider.getBool/setBool`、shared `SectionHeader(title)`。
- **不回归**：`appConfigProvider`→`NotifierProvider` 仅影响 5 处 override（A 一并改）；首启 redirect 影响 **4** 个既有测试（E Step7 预置 `seenOnboarding:true`，已含 `widget_test.dart`——较 M6 plan 多 1 个）；首页副标题只新增不改原断言（H Step1 警示）；`_AiTracePanel` 非演示模式返回空白（C 不影响既有推荐页测试）；设置/对比等切换经 `ref.watch(appConfigProvider)` 自动重建。Task K 跑全量回归。
- **较 M6 plan 的修正**：①override 迁移 2 处 → **5 处**（M3/M4/M5 已落地）；②redirect 受影响测试 3 → **4**（含 `widget_test.dart`）；③视觉去靛蓝/青绿，全程 Bento（取代 M6 §2.4）；④复用 Phase 0 共享 `SectionHeader`（不自造 `_SectionHeader`）；⑤引导升级为**可滑动 `PageView`+圆点+跳过**（Bento §4.2）；⑥新增 Task F 补 Phase 0 遗留字体；⑦onboarding key 用 `seenOnboarding`（非 `seen_onboarding`）；⑧三态打磨已由 Phase 0 完成，不重复。
```