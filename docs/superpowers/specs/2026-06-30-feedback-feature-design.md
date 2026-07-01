# 反馈功能设计 (Feedback Feature)

- 日期: 2026-06-30
- 分支: iter4rc2
- 状态: 设计已确认,待实现

## 1. 背景与目标

用户在使用 SchoNavi 时可能遇到:推荐结果不符合预期、系统未收录某位导师、
App 出现 bug,或想提其他建议。当前 App 没有统一反馈通道。

v1 反馈功能定位为**数据质量改进回路**:

- APP 端做带上下文的反馈提交(全局入口 + 场景内联)。
- 后端做人工审查队列(本次不实现后端代码,仅定契约 + 文档,后续排期)。
- APP 不参与审查流程。

补 AIGC 大模型应用评分短板(数据回流改进推荐)。

## 2. 范围

### In scope

- `Feedback` 领域实体 + `FeedbackType` 枚举。
- `FeedbackRepository` 抽象接口。
- `http` 实现 + `mock` 实现(按 `DataSource` 路由)。
- `feedbackRepositoryProvider`(llm → mock,http → http)。
- 反馈页 `/feedback`(表单 + 类型选择 + 上下文摘要)。
- 抽屉全局入口 + 三个场景内联入口(推荐卡 / 导师详情 / 备赛助手)。
- `FeedbackEntryButton` 复用组件。
- HTTP 契约:客户端 DTO + `api-contract.md` 段 + `openapi.yaml` path。
- 上述单元/widget/契约测试。

### Out of scope

- `web/backend` 端点实现(后续排期)。
- 本地草稿保存 / 离线重试 / 反馈历史查看页 / admin 审查界面。

## 3. 决策摘要

| 维度 | 决策 |
| --- | --- |
| 定位 | 数据质量改进回路;人工审查在 APP 之外 |
| 入口 | 全局(抽屉)+ 场景内联,共用 `/feedback` 页 |
| 提交 | APP 走 HTTP Repository 抽象;本次不改 `web/backend` |
| 落地 | 失败即报错,不本地保存,不重试 |
| 上下文 | 自动携带 route/session/message/professor/competition/prompt/version/mode |
| 类型 | recommendation / missingProfessor / bug / other |
| 模式 | http 实现 + mock 实现;llm 模式回退 mock;演示模式走 mock |
| 联系方式 | 可选字段 |
| HTTP 契约 | 客户端 DTO + `api-contract.md` + `openapi.yaml`;后端代码后续排期 |

## 4. 架构与分层

严格分层,与现有 8 个 repository 同构。未来接后端只需补 HTTP 实现 + 切 provider。

```text
domain/
  entities/feedback.dart                 Feedback 实体 + FeedbackType + FeedbackContext
  repositories/feedback_repository.dart  抽象接口 submit(Feedback) → Result<Unit>
data/
  dto/feedback_dto.dart                 Feedback ↔ JSON(snake_case)
  http/http_feedback_repository.dart     POST /v1/feedback
  mock/mock_feedback_repository.dart     伪造 200 + 600ms 延迟
core/di/providers.dart
  feedbackRepositoryProvider            DataSource.llm→mock, .http→http
features/feedback/
  pages/feedback_page.dart               表单页
  providers/feedback_provider.dart        Notifier: loading/success/error
  widgets/feedback_entry_button.dart     场景内联按钮
core/router/app_router.dart              注册 /feedback?...= 路由
```

模式路由规则与 [lib/core/di/providers.dart](../../../lib/core/di/providers.dart) 现有约定一致
(`DataSource.llm` → 本地实现,`DataSource.http` → HTTP 实现)。
llm 模式回退 mock(反馈不需要 LLM 能力)。

## 5. 实体与契约

### 5.1 领域实体

`domain/entities/feedback.dart`:

```dart
enum FeedbackType { recommendation, missingProfessor, bug, other }

class FeedbackContext {
  final String? route;            // 当前页路由,如 /professor/P001
  final String? sessionId;        // 对话会话 id
  final String? messageId;        // 被反馈的推荐消息 id
  final String? professorId;      // 教授 id
  final String? competitionId;    // 竞赛 id
  final String? prompt;            // 当时的输入
  final String appVersion;         // 来自 appConfig
  final String dataSourceMode;     // llm/http/mock

  /// 从路由 query 参数还原上下文。
  factory FeedbackContext.fromQuery(Map<String, String> q);
}

class Feedback {
  final String id;                // 客户端生成 UUID
  final FeedbackType type;
  final String content;           // 必填,用户描述
  final String? contact;          // 可选联系方式
  final FeedbackContext context;
  final DateTime createdAt;
}
```

### 5.2 DTO

`data/dto/feedback_dto.dart`,风格对齐
[chat_message_dto.dart](../../../lib/data/dto/chat_message_dto.dart):

```dart
class FeedbackDto {
  const FeedbackDto({
    required this.id,
    required this.type,
    required this.content,
    required this.contact,
    required this.context,
    required this.createdAt,
  });

  final String id;
  final String type;           // recommendation|missing_professor|bug|other
  final String content;
  final String? contact;
  final FeedbackContextDto context;
  final String createdAt;      // ISO8601

  factory FeedbackDto.fromEntity(Feedback f);
  factory FeedbackDto.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

snake_case ↔ camelCase 转换,`created_at` 默认 `DateTime.now().toIso8601String()`。

### 5.3 Repository 接口

`domain/repositories/feedback_repository.dart`:

```dart
abstract class FeedbackRepository {
  Future<Result<Unit>> submit(Feedback feedback);
}
```

`Result<T>` 复用 [lib/core/result/result.dart](../../../lib/core/result/result.dart)。

### 5.4 HTTP 实现

`data/http/http_feedback_repository.dart`,走 `apiDioProvider`(真实后端模式):

- `POST /api/v1/feedback`,body = `FeedbackDto.toJson()`。
- 响应遵循项目统一信封 `{ code, message, data }`(对齐现有 8 个 http repo,
  复用 `guardApi`/`decodeEnvelope`):
  `{ "code": 0, "message": "ok", "data": { "id","status":"received","received_at" } }`
  → `Success(Unit())`。
- `code != 0` → `Failure(ValidationException(message))`(由 `decodeEnvelope` 抛出)。
- 网络异常 → `Failure(mapDioException(error))`(`TimeoutException` / `NetworkException` 等)。

### 5.5 Mock 实现

`data/mock/mock_feedback_repository.dart`:

- 600ms 模拟延迟后返回 `Success(Unit())`。
- 演示模式 / llm 模式 / 测试均走此实现。

### 5.6 Provider

`core/di/providers.dart`:

```dart
final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return switch (cfg.dataSource) {
    DataSource.http => HttpFeedbackRepository(ref.watch(apiDioProvider)),
    DataSource.llm   => MockFeedbackRepository(),
  };
});
```

## 6. HTTP 契约

本次只定义客户端 DTO + 文档,不写后端代码。遵循项目统一信封
`{ code, message, data }`(对齐现有 8 个 http repo,复用 `guardApi`)。

### `POST /api/v1/feedback`

请求体:

```json
{
  "id": "uuid",
  "type": "recommendation | missing_professor | bug | other",
  "content": "推荐了一位做 CV 的老师,但我想要的是 NLP",
  "contact": "可选",
  "context": {
    "route": "/professor/P001",
    "session_id": "...",
    "message_id": "...",
    "professor_id": "P001",
    "competition_id": null,
    "prompt": "我想找 NLP 方向的导师",
    "app_version": "1.2.0",
    "data_source_mode": "http"
  },
  "created_at": "2026-06-30T12:00:00Z"
}
```

响应 `200`(信封):

```json
{
  "code": 0,
  "message": "ok",
  "data": { "id": "...", "status": "received", "received_at": "2026-06-30T12:00:01Z" }
}
```

失败: `code != 0`(业务失败)或 `4xx/5xx`(网络/服务端)。
客户端不重试、不保存,`SnackBar('反馈提交失败,请稍后重试')`。

写入:

- [docs/api-contract.md](../../../docs/api-contract.md) 新增 "Feedback" 段。
- [docs/openapi.yaml](../../../docs/openapi.yaml) 加 `/api/v1/feedback` path
  + `UserFeedbackRequest` / `UserFeedbackEnvelope` schema
  (避免与已有 `FeedbackRequest`(消息点赞)重名)。

## 7. Provider、页面与入口

### 7.1 Provider

`features/feedback/providers/feedback_provider.dart`:

```dart
class FeedbackSubmitState {
  const FeedbackSubmitState({
    this.loading = false,
    this.success = false,
    this.errorMessage,
  });

  final bool loading;
  final bool success;
  final String? errorMessage;

  FeedbackSubmitState copyWith({bool? loading, bool? success, String? errorMessage});
}

class FeedbackSubmitNotifier extends Notifier<FeedbackSubmitState> {
  @override
  FeedbackSubmitState build() => const FeedbackSubmitState();

  Future<void> submit(Feedback feedback) async {
    state = state.copyWith(loading: true, errorMessage: null);
    final result = await ref.read(feedbackRepositoryProvider).submit(feedback);
    state = switch (result) {
      Success<Unit>() => state.copyWith(loading: false, success: true),
      Failure<Unit>(:final error) => state.copyWith(
          loading: false, errorMessage: error.message),
    };
  }
}
```

`Notifier`(非 autoDispose):提交成功后跳回上一页前状态保留一帧,
避免 pop 时状态丢失导致 SnackBar 不显示。

### 7.2 反馈页

`features/feedback/pages/feedback_page.dart`:

- 顶部 4 个 `FeedbackType` chip(单选),从 `?type=` 预选。
- `content` 多行文本框(必填,最少 5 字)。
- `contact` 单行(可选)。
- 自动采集上下文以折叠摘要展示("已附加:导师 P001 / 会话 … / prompt …"),
  只读,让用户知道带了什么。
- 底部"提交"按钮,loading 时禁用。
- 成功 → `SnackBar('感谢反馈,我们会尽快处理')` + `context.pop()`。
- 失败 → `SnackBar('反馈提交失败,请稍后重试')`,留页不丢内容。

### 7.3 路由

`core/router/app_router.dart`:

```dart
GoRoute(
  path: '/feedback',
  pageBuilder: (_, state) => sharedAxisPage(
    state: state,
    child: FeedbackPage(
      type: _parseFeedbackType(state.uri.queryParameters['type']),
      context: FeedbackContext.fromQuery(state.uri.queryParameters),
    ),
  ),
),
```

### 7.4 入口接线

- 抽屉 [app_menu_drawer.dart](../../../lib/shared/widgets/app_menu_drawer.dart)
  在"我的备赛"与"设置"之间插入 `Icons.feedback_outlined` "反馈" tile
  → `/feedback?type=other`。
- 推荐卡 [chat_message_bubble.dart](../../../lib/features/chat/widgets/chat_message_bubble.dart)
  已有 `onFeedback`(点赞),在其旁加溢出菜单"反馈这条推荐"
  → `/feedback?type=recommendation&mid=…&sid=…&prompt=…`。
- 导师详情页 `professor_page` 加 AppBar action 或底部"反馈这位导师信息"
  → `/feedback?type=missing_professor&pid=…`。
- 备赛助手对话内联按钮
  → `/feedback?type=bug&route=/preparation/…`。

内联按钮统一封装为 `FeedbackEntryButton`,接收 type + 上下文参数,
内部 `context.push('/feedback?…')`。

## 8. 错误处理

- http 模式:网络异常 / 非 2xx → `Failure(NetworkException / ServerException)`。
- llm / 演示模式 → mock 实现,返回 `Success` + 600ms 延迟(演示闭环)。
- 提交失败:页面留内容、`SnackBar('反馈提交失败,请稍后重试')`,
  不本地保存、不重试。

## 9. 测试

对照 [test/data/http/http_repositories_test.dart](../../../test/data/http/http_repositories_test.dart)
与 mock 测试风格:

- `test/data/feedback_dto_test.dart` — DTO ↔ JSON 序列化往返。
- `test/data/http_feedback_repository_test.dart` — dio adapter mock:200 成功、500 失败。
- `test/data/mock_feedback_repository_test.dart` — mock 返回 `Success`。
- `test/features/feedback/feedback_page_test.dart` — widget test:
  必填校验、类型预选、提交成功 pop、提交失败留页。
- `test/features/home/home_page_test.dart` — 抽屉出现"反馈"tile、点击跳 `/feedback`。
- `test/docs/api_contract_test.dart` — 校验 `openapi.yaml` 含 `/v1/feedback`
  且与 DTO 一致(对照现有契约测试)。

## 10. 验证清单

1. `dart format --set-exit-if-changed lib test`
2. `flutter analyze`
3. 上述 `flutter test` 文件
4. 手动起 App 走抽屉入口 + 导师详情内联入口各提交一次
   (mock 模式可见成功闭环)

## 11. 既有约定遵守

- 分层:UI/features 依赖 domain 抽象,实现落 `lib/data`,DI 落 `providers.dart`。
- Riverpod 手写 provider(非 generated)。
- `Result`-style + mock/local 实现与附近代码一致。
- mock/本地路径在测试与演示可用。
- 不引入新状态管理 / 路由 / 持久化 / HTTP 库。
- 不写后端 `.env`,secrets 不落仓库。
- 不主动 commit/push(遵循 CLAUDE.md)。
