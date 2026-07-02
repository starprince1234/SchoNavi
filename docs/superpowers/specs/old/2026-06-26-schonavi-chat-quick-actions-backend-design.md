# 对话快捷输入后端化设计

日期：2026-06-26
状态：已确认，待转入实现计划

## 背景与动机

对话页底部输入框上方的快捷操作 chip（「换一批」「只看北京」等）目前是**部分硬编码**的：

- 推荐轮的 chip 已经从后端来——LLM 模式下 [ai_recommendation_repository.dart:186](lib/data/ai/ai_recommendation_repository.dart#L186) 的 prompt 要求模型生成 1-4 个短操作；mock 模式下 [mock_db.dart:143](lib/data/mock/mock_db.dart#L143) 也返回结构化列表。这条链路不动。
- 真正「固定」的是硬编码兜底常量 `defaultChatQuickActions = ['解释理由','换一批','只看北京','适合硕士']`（[chat_quick_actions.dart:7](lib/features/chat/widgets/chat_quick_actions.dart#L7)），以及 chat_page / home_page 各自复制的同名常量。它在两个场景出现：**初始态/纯对话轮**（`_streamConversation` 不刷新 `followUpQuestions`）和**后端返回空时**。

目标：让快捷操作在**每轮助手回复后（含初始态、对话轮、推荐轮）都由后端生成**，硬编码常量仅作网络失败兜底。这同时是参赛评分「大模型应用能力」维度的增量——多一处 LLM 驱动的对话内容生成。

本次迁移有完全同构的先例可循：need-classifier 从硬编码关键词迁到 `POST /api/v1/chat/route`（[http_recommendation_need_classifier.dart](lib/data/http/http_recommendation_need_classifier.dart) + [fake_chat_route_backend.dart](lib/data/mock/fake_chat_route_backend.dart) + DTO + 按 `DataSource` 切换的 provider + 失败降级）。本次照搬该模子。

## 决策摘要

| 决策点 | 选择 |
|---|---|
| 覆盖范围 | 全覆盖——每轮助手回复后（推荐+对话）+ 会话初始态都由后端刷新 chip |
| 推荐轮 chip 来源 | 不动，仍用 `RecommendationResult.followUpQuestions`（本就是后端生成） |
| 失败降级 | 网络失败/异常 → 硬编码兜底常量；后端成功但返回空 → 不显示 chip |
| 接口返回类型 | `Result<List<String>>`（区分「失败」与「成功空」，对齐降级规则） |
| 请求上下文 | 对称 `/chat/route`：`follow_up` + 可选 `last_recommendations` recap（cap 5） |
| 交付机制 | 新增独立端点 `POST /api/v1/chat/quick-actions`，与 `/chat/route` 并列 |
| 竞态防护 | 复用 `_operation` token + `_isCurrent`，过期 fetch 丢弃；`start()` 引入 token 守护 |

## 架构方案（方案 1：新增独立端点）

照搬 `/chat/route` 的迁移模子：HTTP 实现 + 假后端 handler + DTO + 按 `DataSource` 切换的 provider + 失败降级。调用时机：对话轮 stream `onDone` 后调一次、会话 `start()` 时调一次；推荐轮仍用 `RecommendationResult.followUpQuestions`，不重复调。

否决的方案：

- **方案 2（对话流里加 SSE 事件 `event: quick_actions`）**：对话流回复顺便带 chip，无额外往返。但初始态没有流→仍要单独路径；LLM 对话流当前是纯文本 delta，改成结构化事件需改 LLM 对话协议，过重；不能独立刷新 chip。不采纳。
- **方案 3（扩展 `/chat/route` 响应顺带返回 chip）**：路由判定时一并返回 chip，不新增端点。但不覆盖初始态（`/chat/route` 只在追问轮触发）；路由判定与 chip 生成耦合；与已确认的「全覆盖」决策冲突。不采纳。

### 三个场景的数据流

```
① 会话 start()
   → ChatNotifier 调 quickActionsSourceProvider.fetch(followUp:'', lastResult:最近推荐)
   → Failure → state.followUpQuestions = defaultChatQuickActions（硬编码兜底）
   → Success([]) → state.followUpQuestions = [] （不显示）
   → Success([...]) → state.followUpQuestions = 后端列表（widget 显示时仍归一化：过滤问句、cap 4、去重）

② 推荐轮 _requestRecommendations()  ← 不动
   → 仍用 data.followUpQuestions 写入 state.followUpQuestions

③ 对话轮 _streamConversation() 的 onDone
   → ChatNotifier 调 quickActionsSourceProvider.fetch(followUp:用户刚发的话, lastResult:最近推荐)
   → 同 ① 的降级规则
```

`ChatState.followUpQuestions` 字段语义不变（仍是「当前要展示的 chip 列表」），`ChatQuickActions` widget 的展示逻辑零改动，只是**填充来源**从「只有推荐轮写」扩展为「推荐轮 + 对话轮 + 初始态都写」。**关键：fallback 的所有权从 widget 上移到 ChatNotifier**——见 §7，widget 的 `fallback` 参数须中和为空，否则 `Success([])` 会被 widget 的兜底覆盖成硬编码常量，破坏「空则不显示」。

## 详细设计

### 1. 领域接口

新建 `lib/shared/utils/quick_actions_source.dart`（与 `recommendation_need_classifier.dart` 同层），抽象接口对称 `RecommendationNeedClassifier`：

```dart
import '../../core/result/result.dart';
import '../../domain/entities/recommendation_result.dart';

/// 快捷操作的后端来源。返回 [Result] 以区分「失败」与「成功但空」——
/// 失败由调用方降级到硬编码兜底，成功空则不显示 chip（对齐 spec 降级规则）。
abstract interface class QuickActionsSource {
  Future<Result<List<String>>> fetch({
    required String followUp,
    RecommendationResult? lastResult,
  });
}
```

**为什么 `Result<List<String>>` 而非裸 `List<String>`：** 裸列表无法区分「网络失败的空」与「后端成功返回的空」。`Failure` → 调用方填兜底常量；`Success([])` → 调用方置空不显示。这与 `RecommendationNeedClassifier` 把降级放实现内部不同——因为这里「失败」和「空」在 ChatNotifier 里要区别对待。

### 2. DTO

新建 `lib/data/dto/quick_actions_dto.dart`，对称 `route_need_dto.dart`，复用 `RecommendationRecapDto`（与 `/chat/route` 同款摘要，避免端点间 DTO 重复）：

```dart
import 'recommendation.dart';
import 'api_envelope.dart';

/// 请求体：{"follow_up": "...", "last_recommendations": [...]}
/// follow_up 缺省/空字符串表示会话开始，后端按通用 chip 语义返回。
class QuickActionsRequestDto {
  const QuickActionsRequestDto({required this.followUp, this.lastRecommendations});

  final String followUp;
  final List<RecommendationRecapDto>? lastRecommendations;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'follow_up': followUp,
    if (lastRecommendations != null)
      'last_recommendations': [for (final r in lastRecommendations!) r.toJson()],
  };
}

/// 响应 data：{"quick_actions": ["换一批","偏应用",...]}
/// quick_actions 缺省/类型错误 → 视为空 []（由 fromJson 兜底），不报错。
class QuickActionsResponseDto {
  const QuickActionsResponseDto({required this.quickActions});

  final List<String> quickActions;

  factory QuickActionsResponseDto.fromJson(Map<String, dynamic> json) {
    final list = json['quick_actions'];
    return QuickActionsResponseDto(
      quickActions: list is List
          ? list
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList(growable: false)
          : const <String>[],
    );
  }
}
```

### 3. 端点契约

写入 `docs/api-contract.md`，紧跟 `/chat/route` 一节：

```
POST /api/v1/chat/quick-actions

Request:
{ "follow_up": "只看上海的导师",          # 可空字符串，会话开始时为 ""
  "last_recommendations": [ {...recap...} ]  # 可选，首轮省略
}
Response data:
{ "quick_actions": ["换一批","偏应用","只看985","适合博士"] }
```

`follow_up` 缺省视为空字符串。`last_recommendations` 首轮省略，后续轮由调用方 cap 到 5 条。`quick_actions` 缺省/类型错误由 DTO 兜底为空 `[]`，不报错——对齐「后端返回空则不显示」。

### 4. 两个实现 + 假后端

**HTTP 实现（`lib/data/http/http_quick_actions_source.dart`，对称 `http_recommendation_need_classifier.dart`）：**

```dart
class HttpQuickActionsSource implements QuickActionsSource {
  HttpQuickActionsSource(this._dio);
  final Dio _dio;

  @override
  Future<Result<List<String>>> fetch({
    required String followUp,
    RecommendationResult? lastResult,
  }) async {
    return guardApi(
      () => _dio.post<dynamic>(
        '/api/v1/chat/quick-actions',
        data: QuickActionsRequestDto(
          followUp: followUp,
          lastRecommendations: lastResult == null
              ? null
              : [for (final r in lastResult.recommendations.take(5))
                  RecommendationRecapDto.fromEntity(r)],
        ).toJson(),
      ),
      (data) => QuickActionsResponseDto.fromJson(asJsonObject(data)).quickActions,
    );
  }
}
```

`guardApi` 把信封/Dio 错误塌缩为 `Failure`，成功时返回 `Success<List<String>>`——`Result` 透传，不在实现内部做降级（降级决策交回 ChatNotifier）。

**LLM 实现（`lib/data/ai/llm_quick_actions_source.dart`，对称 `llm_recommendation_need_classifier.dart`）：**

```dart
class LlmQuickActionsSource implements QuickActionsSource {
  LlmQuickActionsSource(this._llm);
  final LlmClient _llm;

  @override
  Future<Result<List<String>>> fetch({
    required String followUp,
    RecommendationResult? lastResult,
  }) async {
    final res = await _llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', _userPrompt(followUp, lastResult)),
      ],
      jsonMode: true,
      temperature: 0.8,   // chip 略带多样性，避免每轮雷同
    );
    if (res is Failure<String>) return Failure(res.error);

    try {
      final decoded = jsonDecode((res as Success<String>).data);
      if (decoded is! Map<String, dynamic>) return const Success(<String>[]);
      final list = decoded['quick_actions'];
      if (list is! List) return const Success(<String>[]);
      final actions = list
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      return Success(actions);
    } catch (_) {
      return const Success(<String>[]);   // 畸形输出降级为成功空
    }
  }
}
```

LLM prompt 复用 [ai_recommendation_repository.dart:186](lib/data/ai/ai_recommendation_repository.dart#L186) 已有的短操作规则（1-4 个、≤8 汉字、操作短语、不含问号、不以「你/是否/请问」开头），输出 `{"quick_actions":[...]}`。畸形输出降级为 `Success(<String>[])`（视为「后端成功但无建议」，不显示 chip，不触发硬编码兜底）；LLM 调用本身失败返回 `Failure`（触发兜底）。

**假后端 handler（`lib/data/mock/fake_chat_quick_actions_backend.dart`，对称 `fake_chat_route_backend.dart`）：**

```dart
/// 假后端对 POST /api/v1/chat/quick-actions 的处理：读 follow_up + last_recommendations，
/// 调纯函数 _pickByContext 挑 chip，按 API 信封约定返回。
Future<ResponseBody> chatQuickActionsHandler(RequestOptions options) async {
  final data = options.data;
  final followUp = data is Map<String, dynamic>
      ? (data['follow_up']?.toString() ?? '')
      : '';
  final recaps = data is Map<String, dynamic>
      ? (data['last_recommendations'] as List? ?? const [])
      : const [];
  final actions = _pickByContext(followUp, recaps);
  return _jsonEnvelope(actions);
}

/// 纯函数，便于单测。关键词驱动：
/// - followUp 空（首轮/会话开始）→ 通用 4 个
/// - 含「换/再推荐」→ 换一批系
/// - 含「只看/地区」→ 筛选系
/// - 否则 → 上一轮方向相关
List<String> _pickByContext(String followUp, List recaps) { ... }
```

`_pickByContext` 是纯函数（像 `followUpNeedsRecommendations` 那样可独立单测），保证 mock 模式下 chip 也会随会话变化、而非恒定硬编码。注册到 `FakeBackendAdapter._defaultHandlers()`，与 `/chat/route` 并列：

```dart
Map<_RouteKey, Future<ResponseBody> Function(RequestOptions)> _defaultHandlers() {
  return {
    _RouteKey('POST', '/api/v1/chat/route'): chatRouteHandler,
    _RouteKey('POST', '/api/v1/chat/quick-actions'): chatQuickActionsHandler,
  };
}
```

### 5. Provider

新建 `lib/core/di/providers.dart` 内，对称 `recommendationNeedClassifierProvider`：

```dart
final quickActionsSourceProvider = Provider<QuickActionsSource>((ref) {
  return switch (ref.watch(appConfigProvider).dataSource) {
    DataSource.llm => LlmQuickActionsSource(ref.watch(llmClientProvider)),
    DataSource.http => HttpQuickActionsSource(ref.watch(dioProvider)),
  };
});
```

### 6. ChatNotifier 集成 + 竞态防护

`ChatState.followUpQuestions` 字段、`copyWith` 不变。新增私有方法 `_refreshQuickActions`，在三个调用点触发（都用 token 防竞态）：

```dart
Future<void> _refreshQuickActions({
  required String followUp,
  required int token,
}) async {
  final result = await ref.read(quickActionsSourceProvider).fetch(
    followUp: followUp,
    lastResult: _lastRecommendationResult(),
  );
  if (!_isCurrent(token)) return;          // 过期请求丢弃
  final actions = result is Success<List<String>> && result.data.isNotEmpty
      ? result.data
      : (result is Failure ? defaultChatQuickActions : const <String>[]);
  state = state.copyWith(followUpQuestions: actions);
}
```

降级分支：`Success` 且非空 → 展示；`Failure` → 硬编码兜底；`Success([])` → 空列表不显示。

**调用点 ①：`start()` 末尾（新增 token 守护）**

```dart
void start({required String sessionId, String? professorId}) {
  if (state.sessionId == sessionId && state.professorId == professorId) {
    return;
  }
  final token = _beginOperation();           // ← 新增：让初始 fetch 纳入操作计数
  final sub = _sub;
  _sub = null;
  _activeAssistantId = null;
  if (sub != null) unawaited(sub.cancel());
  _completeTurn();

  _seq = 0;
  state = ChatState(
    sessionId: sessionId,
    professorId: professorId,
    messages: const [],
    activity: ChatActivity.idle,
    followUpQuestions: const [],
  );
  unawaited(_refreshQuickActions(followUp: '', token: token));
}
```

**调用点 ②：推荐轮 `_requestRecommendations` 成功分支——不动**，仍写 `followUpQuestions: data.followUpQuestions`。

**调用点 ③：对话轮 `_streamConversation` 的 `onDone`**

```dart
onDone: () {
  if (_isCurrent(token)) {
    _setAssistant(assistantId, buffer.toString(), ChatMessageStatus.done);
    state = state.copyWith(activity: ChatActivity.idle);
    unawaited(_refreshQuickActions(followUp: content, token: token));
  }
  _clearActiveTurn(turn: turn, assistantId: assistantId);
},
```

`onError` 分支不刷新 chip（保留上一轮 chip，避免错误态突然空白）。

**竞态防护要点：**

| 场景 | 防护 |
|---|---|
| 用户连发两条 | `_beginOperation()` 自增 token，旧 fetch 回来时 `_isCurrent(token)` 为 false → 丢弃 |
| fetch 比流式回复还慢 | 同上，token 守护 |
| `start()` 重置后旧 fetch 才回来 | `start()` 内 `_operation++`，旧 fetch 的 token 失效 |
| 推荐轮进行中又触发 chip fetch | 推荐轮不调 `_refreshQuickActions`，只有对话轮和初始态调，天然不冲突 |
| `stop()` 中断流式 | `stop()` 已 `_operation++`，被中断轮的 onDone 里 `_isCurrent(token)` 为 false → 不刷新 chip |
| `start()` 后紧跟 `bootstrapRecommendations()` | bootstrap 内部 `_beginOperation()` 自增，会接管 token；若 start 的初始 fetch 慢于 bootstrap 推荐完成，start 的旧 fetch token 失效被丢弃，不会覆盖 bootstrap 写入的 `followUpQuestions` |

### 7. UI 层

`ChatQuickActions` widget 的**展示逻辑零改动**（仍 `normalizeChatQuickActions` 过滤问句、cap 4、去重 + `isEmpty → SizedBox.shrink`），但**`fallback` 参数须中和为空**：

- widget 构造参数默认值从 `fallback = defaultChatQuickActions` 改为 `fallback = const <String>[]`。
- chat_page ([chat_page.dart:199](lib/features/chat/pages/chat_page.dart#L199)) 与 home_page ([home_page.dart:535](lib/features/home/pages/home_page.dart#L535)) 删除 `fallback: _quickActions` 入参，并删除两处复制的 `static const _quickActions` / `const _quickActions` 私有常量。

**为什么必须中和：** `normalizeChatQuickActions(actions, fallback)` 在 `actions` 归一化为空时回退到 `fallback`（[chat_quick_actions.dart:22-31](lib/features/chat/widgets/chat_quick_actions.dart#L22-L31)）。若 widget 仍持有非空 `fallback`，ChatNotifier 写入 `followUpQuestions = []`（`Success([])` → 不显示）时，widget 会用 `fallback` 渲染出硬编码常量，**破坏「空则不显示」**。把 fallback 所有权上移到 ChatNotifier（`Failure → defaultChatQuickActions`），widget 的 fallback 中和为空，`Success([])` 才能真正隐藏。

`defaultChatQuickActions` 常量保留在 `chat_quick_actions.dart`，改由 ChatNotifier 导入使用（作 `Failure` 兜底来源）。widget 自身不再依赖它做兜底。

## 测试策略

按 TDD，每个单元先写测试再写实现。**所有测试纯前端可运行，无需真后端、真 LLM、真网络**——HTTP 层用 `_FakeAdapter` 拦截 Dio，LLM 层用 `_FakeLlm` 返回预设 JSON，ChatNotifier 层用假 `QuickActionsSource` + `ProviderContainer` override。

### ① 假后端纯函数（`test/data/mock/fake_chat_quick_actions_backend_test.dart` — 新建）

直接调 `chatQuickActionsHandler` / `_pickByContext`，对称 `follow_up_routing_test.dart`：

- `followUp` 空 → 返回通用 4 个 chip
- 含「换一批/再推荐」→ 返回换一批系
- 含「只看/北京」→ 返回筛选系
- `last_recommendations` 缺省/非 Map → 不崩，按空 recap 处理
- 信封格式：`{code:0, message:'ok', data:{quick_actions:[...]}}`
- `FakeBackendAdapter` 把 `POST /api/v1/chat/quick-actions` 分派到 handler；未注册路径仍 404（回归）

### ② HTTP 实现（`test/data/http/http_quick_actions_source_test.dart` — 新建）

用 `_FakeAdapter`（复用 need-classifier 测试同款），对称 `http_recommendation_need_classifier_test.dart`：

- 请求体含 `follow_up`、`last_recommendations` recap（professor_id/name/university/research_fields）
- `lastResult` 为 null 时省略 `last_recommendations`
- recap cap 到 5 条
- 解码 `quick_actions` 列表
- 非零信封 → `Failure`
- 畸形 success data → `Failure`
- DioException → `Failure`
- **返回 `Result` 而非裸列表**（断言 `Success`/`Failure` 类型，与 need-classifier 测试不同点）

### ③ LLM 实现（`test/data/ai/llm_quick_actions_source_test.dart` — 新建）

用 `_FakeLlm`（复用 need-classifier 测试同款），对称 `llm_recommendation_need_classifier_test.dart`：

- `{"quick_actions":["换一批","偏应用"]}` → `Success(['换一批','偏应用'])`
- 畸形输出 → `Success(<String>[])`（注意：畸形降级为成功空，不是 Failure）
- LLM 失败 → `Failure`
- prompt 含上一轮推荐摘要（断言 user message 含导师名/方向）

### ④ ChatNotifier 集成（`test/features/chat/chat_notifier_test.dart` — 扩展）

用假 `QuickActionsSource` + `ProviderContainer` override，扩展现有测试文件：

```dart
// 可编程的假 QuickActionsSource
class _FakeQuickActionsSource implements QuickActionsSource {
  Completer<Result<List<String>>>? _pending;
  Result<List<String>>? _next;
  // 可配置：next/future 控制返回值与时序
}

final container = ProviderContainer(overrides: [
  quickActionsSourceProvider.overrideWithValue(fakeSource),
  chatRepositoryProvider.overrideWithValue(_StreamChatRepo(...)),
]);
```

代表性 case：

- `start()` 后 `followUpQuestions` 来自后端 `Success([...])`
- 后端 `Failure` → `followUpQuestions == defaultChatQuickActions`
- 后端 `Success([])` → `followUpQuestions` 为空
- 对话轮 stream `onDone` 后刷新 chip（`send` → pump → 断言新 chip）
- `onError` 不刷新 chip（保留上一轮）
- **过期 fetch 不覆盖新 state（token 竞态）**：第一次 fetch 挂起（`Completer`），期间 `send` 第二次，第一次 `complete(Success(['旧值']))` 回来后断言 state 仍是 `['新值']`

### ⑤ Widget 层回归（`test/features/chat/widgets/chat_quick_actions_test.dart` — 扩展）

现有「chip 纤细高度」测试保留（`actions: ['换一批']` 非空，不受 fallback 改动影响）。**新增**覆盖 fallback 中和：

- `actions: []`（不传 fallback，走新的空默认）→ `find.byType(SizedBox)` 命中 shrink，不渲染任何 chip——验证 `Success([])` 能真正隐藏，不会被兜底常量覆盖。
- `actions: []` + 显式 `fallback: defaultChatQuickActions` → 仍显示兜底（证明 `fallback` 参数本身行为不变，只是默认值改了，调用方控制权完整）。

**回归保护：** 跑全量 `flutter test`。**必须更新的现有测试**（否则会发起真实网络调用且时序变异步）：

- `test/features/chat/chat_page_test.dart`、`test/features/home/home_page_conversation_test.dart` 等挂载 ChatPage/HomePage 的 widget 测试，当前用 `DataSource.llm + apiKey:'test-key'`，chip 来自 widget 同步兜底。改动后 `start()` 会异步调 `quickActionsSourceProvider` → 解析到 `DeepSeekLlmClient` → 真实网络调用。**须在这些测试的 `ProviderScope.overrides` 里加 `quickActionsSourceProvider.overrideWithValue(<假>)`**，假源返回 `Failure`（→ `defaultChatQuickActions`，与旧 `_quickActions` 同内容）或 `Success([...])`，让 chip 来源确定且离线。
- 这些测试里 `find.text('换一批')` / `'适合硕士'` / `'解释理由')` 在假源返回 `Failure` 时仍命中（`defaultChatQuickActions` 与旧 `_quickActions` 内容一致），tap 流程不变；若假源返回 `Success([...])` 则断言要改成对应内容。实现阶段逐个核对。
- `chat_notifier_test.dart` 已用 `ProviderContainer` override，加 `quickActionsSourceProvider` override 即可（见 ④）。

## 影响范围

**新增文件：**

- `lib/shared/utils/quick_actions_source.dart` — 领域接口
- `lib/data/dto/quick_actions_dto.dart` — 请求/响应 DTO
- `lib/data/http/http_quick_actions_source.dart` — HTTP 实现
- `lib/data/ai/llm_quick_actions_source.dart` — LLM 实现
- `lib/data/mock/fake_chat_quick_actions_backend.dart` — 假后端 handler + `_pickByContext`
- `test/data/mock/fake_chat_quick_actions_backend_test.dart`
- `test/data/http/http_quick_actions_source_test.dart`
- `test/data/ai/llm_quick_actions_source_test.dart`

**改动文件：**

- `lib/core/di/providers.dart` — 新增 `quickActionsSourceProvider`
- `lib/features/chat/providers/chat_provider.dart` — 新增 `_refreshQuickActions`、`start()` 加 token、`_streamConversation` 的 `onDone` 调用、导入 `defaultChatQuickActions`
- `lib/features/chat/widgets/chat_quick_actions.dart` — `fallback` 参数默认值改为 `const <String>[]`（展示逻辑不动）
- `lib/features/chat/pages/chat_page.dart` — 删除 `fallback: _quickActions` 入参与 `_quickActions` 常量
- `lib/features/home/pages/home_page.dart` — 删除 `fallback: _quickActions` 入参与 `_quickActions` 常量
- `lib/data/mock/fake_backend.dart` — `_defaultHandlers` 注册新端点
- `docs/api-contract.md` — 追加 `POST /chat/quick-actions` 契约
- `test/features/chat/chat_notifier_test.dart` — 扩展三调用点 + 竞态测试

**零改动（验证不变）：**

- `lib/data/ai/ai_recommendation_repository.dart` — 推荐轮 chip 生成不动
- `lib/data/mock/mock_db.dart` — mock 推荐轮 chip 不动
- `lib/features/chat/widgets/chat_quick_questions.dart` — 废弃 wrapper 不动
