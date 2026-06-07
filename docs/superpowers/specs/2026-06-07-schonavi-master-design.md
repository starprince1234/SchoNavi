# SchoNavi APP 主设计文档（Master Design）

- 版本：v1（2026-06-07）
- 适用：SchoNavi 导师推荐系统 APP 端（纯前端阶段，无完整后端）
- 关系：本文是**地基**。三份阶段 spec（V0.1 / V0.2 / V1.0）引用本文，不重复其中的架构/模型/契约定义。
- 输入需求：用户提供的《导师推荐系统 APP 端需求说明》。本文在其基础上做了少量修正，见 §11。

---

## 1. 概述与定位

SchoNavi 是面向学生与科研申请者的**智能导师推荐与咨询工具**。核心闭环：

> 自然语言输入 → 导师推荐 → 查看理由 → 继续追问 → 收藏/反馈

当前阶段**没有完整后端**，采用纯前端开发：App 内置 Mock 仓储 + 真实风格的中文假数据，完全离线可跑（比赛 demo 可演示）；所有数据访问都走抽象接口，将来接入真实后端只需替换实现绑定（见 §3.3）。

设计目标（对应需求 §4）：输入顺畅、结果清晰、理由可信、详情完整、多轮追问可用、收藏/历史可用、接口调用稳定、异常处理完善。

---

## 2. 技术栈与运行环境

| 模块 | 选型 | 说明 |
|---|---|---|
| 框架 / 语言 | Flutter 3.44.1 / Dart 3.12.1（stable） | 当前工程已就绪 |
| 状态管理 | **Riverpod**（`flutter_riverpod`，建议配 `riverpod_annotation` + codegen） | 一开始就用，清晰分层 |
| 路由 | `go_router` | 声明式路由 + 重定向（登录/引导判断） |
| 网络 | `dio` | 仅在 `http` 数据源实现里使用；拦截器做日志/错误映射 |
| 本地存储 | `shared_preferences`（MVP） | 存 JSON：收藏/历史/会话/首启标记/token。后续可换 Hive |
| 外链 | `url_launcher` | 教师主页用系统浏览器打开（MVP 不做内置 WebView） |
| Markdown | `flutter_markdown` 或其社区替代（如 `markdown_widget`/`gpt_markdown`） | **实现时确认可用性**：first-party `flutter_markdown` 已进入弃用流程，落地前在 foundation plan 里核实 |
| 测试 | `flutter_test` + Riverpod `ProviderContainer` | 单元 + widget 测试 |

> 依赖**不在 spec 里写死精确版本**；实现阶段用 `flutter pub add` 解析与 Dart 3.12 兼容的最新 stable，并在 pubspec 里锁定。

**平台与兼容性**（需求 §12.2 / §18.2）：

- Android `minSdk = 31`（Android 12）——当前为 Flutter 默认值，**需在 `android/app/build.gradle.kts` 显式改为 31**（V0.1 地基任务）。
- 主测 Android 真机 + MuMu / Android Studio 模拟器。
- iOS：代码保持平台无关，可在模拟器跑，但不保证上架/测试（开放问题 Q9）。

---

## 3. 架构与分层

### 3.1 分层原则

三层 + 横切 core，presentation 永远只依赖 domain 抽象，不感知数据真假：

```text
presentation (features/*)  →  domain (entities + repository 接口)  ←  data (mock / remote / local 实现)
                                         ↑
                                   core (config / theme / router / network / error / result / di)
```

- **domain**：纯 Dart，无 Flutter/Dio 依赖。定义实体与仓储**抽象接口**。
- **data**：实现接口。`mock/`（内置假数据，当前默认）、`remote/`（Dio 实现，预留）、`local/`（SharedPreferences）。DTO 负责 JSON 序列化，与 entity 分离。
- **presentation**：按 feature 自包含（页面 + 局部 widget + 视图模型 provider）。
- **core**：配置、主题、路由、网络客户端、错误体系、`Result<T>`、依赖注入 provider。

### 3.2 目录结构

```text
lib/
  main.dart                      // runApp(ProviderScope(...))
  app.dart                       // MaterialApp.router + 主题 + 路由
  core/
    config/app_config.dart       // dataSource(mock|http)、apiBaseUrl、appVersion、featureFlags
    theme/                       // app_theme.dart(亮/暗)、colors.dart、spacing.dart、text_styles.dart
    router/app_router.dart       // go_router + redirect(首启/登录)
    network/dio_client.dart      // Dio 实例 + 拦截器（仅 http 数据源用）
    error/app_exception.dart     // AppException 体系 + 错误码映射
    result/result.dart           // sealed Result<T> = Success | Failure
    di/providers.dart            // 顶层 Riverpod provider：仓储绑定在此按 config 切换
    analytics/analytics.dart     // AnalyticsService 接口 + Stub 实现（事件见 §7）
  domain/
    entities/                    // §4 所列实体
    repositories/                // §5 所列抽象接口
  data/
    dto/                         // *_dto.dart + fromJson/toJson（snake_case 对齐 API）
    mock/                        // Mock*Repository + fixtures/（中文假数据）
    remote/                      // Http*Repository（Dio 实现，预留/V1.0 走通）
    local/                       // LocalStore 抽象 + SharedPreferences 实现；SyncService 接口
  features/
    onboarding/  auth/  home/  recommendation/  professor/
    chat/  favorite/  history/  feedback/  compare/  settings/
      <feature>/pages/  <feature>/widgets/  <feature>/providers/
  shared/widgets/                // ProfessorCard、LoadingView、ErrorView、EmptyView、
                                 //  MatchLevelChip、FieldChips、AppScaffold...
```

每个 feature 自包含；跨 feature 复用入 `shared/`；基础设施入 `core/`。文件过大即拆分（单一职责）。

### 3.3 Mock ⇄ 真实后端切换机制（关键）

采用**运行时可切换仓储**（方案 A）：

1. `AppConfig.dataSource` 取 `mock` 或 `http`（默认 `mock`）。
2. 每个仓储一个 Riverpod provider，在 `core/di/providers.dart` 里按 `dataSource` 返回 `Mock*` 或 `Http*` 实现：

```dart
final recommendationRepositoryProvider = Provider<RecommendationRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return switch (cfg.dataSource) {
    DataSource.mock => MockRecommendationRepository(ref.watch(mockDbProvider)),
    DataSource.http => HttpRecommendationRepository(ref.watch(dioClientProvider)),
  };
});
```

3. presentation 层只 `ref.watch(recommendationRepositoryProvider)`，永不感知实现。
4. **接后端 = 写好 `Http*Repository` + 把 `dataSource` 切到 `http`**，presentation 与 domain 零改动。

> 备选：编译期 flavor（`main_mock`/`main_prod`）隔离更彻底但多一套构建配置，对比赛 demo 偏重；单仓储内部 `if(useMock)` 会耦合假数据与生产逻辑、难测——均已否决。

---

## 4. 领域模型与数据契约

实体为纯净领域对象（camelCase）；DTO 负责与 API JSON（snake_case，见需求 §9）互转。下表给出字段与可空性（`?` 表示可空，UI 缺失时显示「暂无信息」，绝不渲染 null/undefined）。

| 实体 | 字段 |
|---|---|
| `Professor`（详情） | id, name, university, college, title, researchFields[], bio?, homepageUrl?, sourceUrl?, updatedAt?, dataQualityScore? |
| `Recommendation`（卡片） | professorId, name, university, college, title, researchFields[], homepageUrl?, matchLevel, matchScore?, reason, limitations[] |
| `QueryUnderstanding` | researchInterests[], preferredLocations[], preferredUniversities[], degreeStage?, uncertainties[] |
| `RecommendationResult` | sessionId, queryUnderstanding, recommendations[], followUpQuestions[] |
| `ChatMessage` | id, role(user/assistant), content, createdAt, relatedRecommendations[], status(sending/streaming/done/error) |
| `ChatResult` | sessionId, answer, relatedRecommendations[] |
| `Feedback` | sessionId?, professorId?, feedbackType(enum), feedbackContent?, createdAt |
| `SearchHistory` | id, prompt, createdAt, sessionId?, summary, recommendationCount?, topFields[] |
| `Favorite` | professorId, name, university, college, title, researchFields[], homepageUrl?, savedAt, note? |
| `User` | id, email, displayName?, token?, isGuest |

**枚举**

- `MatchLevel { high, medium, low }`（显示「高/中/低」）。
- `FeedbackType { helpful, notRelevant, infoError, homepageBroken, fieldMismatch, wantMoreSimilar, other }`（对应需求 §7.9）。
- `DataSource { mock, http }`；`AuthStatus { guest, authenticated }`。

**`matchScore` 处理**（开放问题 Q3「暂不展示但保留接口」）：模型保留 `matchScore`，UI 默认**不渲染分数**、只显示 `matchLevel`；用 `featureFlags.showMatchScore`（默认 false）预留开关。

**序列化要求**：每个 DTO 有 `fromJson`/`toJson`，与 entity 互转（`toEntity()`/`fromEntity()`）。所有 DTO 需有 fromJson↔toJson 往返单测。

---

## 5. 仓储接口（domain/repositories）

所有**远程类**方法返回 `Future<Result<T>>`（统一错误，见 §6）。**本地类**（收藏/历史）直接返回数据并可暴露 `Stream` 供 UI 响应式刷新。

| 接口 | 方法 | 阶段 |
|---|---|---|
| `RecommendationRepository` | `getRecommendations({required String prompt, String? sessionId})` → `Result<RecommendationResult>` | V0.1 |
| `ProfessorRepository` | `getProfessor(String id)` → `Result<Professor>` | V0.1 |
| | `getSimilar(String id)` → `Result<List<Recommendation>>`（详情页「查看相似导师」按钮用） | V1.0；V0.2 仅以对话意图「相似导师」返回 `relatedRecommendations` |
| `ChatRepository` | `sendMessage({required String sessionId, required String message, String? professorId})` → `Result<ChatResult>` | V0.2 |
| | `streamReply({required String sessionId, required String message, String? professorId})` → `Stream<ChatChunk>`（可中断） | V1.0 |
| `FeedbackRepository` | `submitFeedback(Feedback f)` → `Result<void>` | V0.2 |
| `FavoriteRepository` | `list()`；`add(Favorite)`；`remove(String professorId)`；`isFavorite(String professorId)`；`watch()` → `Stream<List<Favorite>>` | V0.2 |
| `HistoryRepository` | `list()`；`add(SearchHistory)`；`delete(String id)`；`clear()`；`watch()` → `Stream<List<SearchHistory>>` | V0.2 |
| `AuthRepository` | `loginWithEmail(String email, String code)` → `Result<User>`；`continueAsGuest()` → `User`；`logout()`；`currentUser`；`watch()` → `Stream<AuthStatus>` | V0.2 |
| `SyncService`（V1.0） | `pushFavorites(...)` / `pullFavorites(...)` / `pushHistory(...)` / `pullHistory(...)`——无后端时本地 no-op | V1.0 |

每个接口在 `data/mock/` 有一份 Mock 实现；远程类在 `data/remote/` 预留 Http 实现（V1.0 走通骨架）。

---

## 6. 横切关注点

### 6.1 统一返回与错误体系

```dart
sealed class Result<T> {}
class Success<T> extends Result<T> { final T data; }
class Failure<T> extends Result<T> { final AppException error; }
```

`AppException` 子类承载**用户可读中文文案**，Dio 拦截器把 HTTP 状态码/网络异常映射到对应类型（需求 §11.3 / §11.5）：

| 类型 | 触发 | UI 文案 |
|---|---|---|
| `NetworkException` | 断网/无连接 | 当前网络不可用，请检查网络后重试 |
| `TimeoutException` | 超时 | 请求超时，请点击重试 |
| `BadRequestException` | 400 | 输入内容不合法 |
| `UnauthorizedException` | 401 | 请先登录 |
| `ForbiddenException` | 403 | 暂无权限 |
| `NotFoundException` | 404 | 信息不存在 |
| `RateLimitException` | 429 | 请求过于频繁，请稍后再试 |
| `ServerException` | 500/5xx | 服务异常，请稍后重试 |
| `UnknownException` | 其它 | 出错了，请稍后重试 |

Mock 实现可按场景注入这些异常，用于演示弱网/报错/空数据（需求 §18.3）。

### 6.2 视图模型与四态

每页一个 Riverpod `AsyncNotifier`/`Notifier`，统一暴露 `loading / data / empty / error` 四态；`shared/widgets` 提供 `LoadingView`、`EmptyView`、`ErrorView`（带「重试」回调）。空结果文案按需求 §11.2（建议放宽条件 + 快捷修改按钮）。

### 6.3 本地存储与「云同步就绪」

- `LocalStore` 抽象，MVP 用 `shared_preferences` 存 JSON（收藏/历史/会话缓存/首启标记/token）。
- 收藏/历史「本地 + 云」：现在仅本地；`SyncService` 接口占位（V1.0），将来接后端实现多设备同步（开放问题 Q4/Q5=是）。
- 用户可清除本地历史/缓存（需求 §12.4/§12.5 隐私）。

### 6.4 流式（V1.0）

`ChatRepository.streamReply → Stream<ChatChunk>`：Mock 把整段答案切片、用定时器逐段 emit 模拟逐字；真实实现接 SSE。UI 支持逐段渲染、**中断生成**（取消订阅）、失败重试、完成态。

### 6.5 安全与隐私

HTTPS-only（http 数据源阶段）；token 安全存储；日志脱敏（不打印敏感信息）；输入长度限制 ≤1000 字；可清除本地历史；隐私政策 / 用户协议页 + 数据删除入口（V1.0）。提示用户勿输入身份证号/手机号/家庭住址等敏感信息（需求 §12.5）。

### 6.6 测试策略（遵循 TDD）

- **单元**：DTO fromJson↔toJson 往返；实体映射；Mock 仓储行为；视图模型状态流转（用 `ProviderContainer` 覆写 provider 注入假仓储）。
- **Widget**：首页输入校验、推荐结果列表、导师卡片、空/错/加载三态、收藏切换。
- 每个功能/修复**先写测试**再实现。

---

## 7. 埋点事件（需求 §14）

`AnalyticsService` 接口 + `StubAnalyticsService`（控制台打印；V1.0 预留 Firebase/友盟 接入点）。事件枚举：

`appOpen`, `submitPrompt`, `viewRecommendation`, `clickProfessor`, `openHomepage`, `sendChatMessage`, `favoriteProfessor`, `submitFeedback`, `requestError`。

---

## 8. 路由表（go_router）

| 路径 | 页面 | 备注 |
|---|---|---|
| `/` | Splash | 判断首启 → onboarding；否则 → home |
| `/onboarding` | 引导页 | 首启后写 `seenOnboarding` |
| `/login` | 登录页 | 邮箱（模拟）+「以游客身份继续」 |
| `/home` | 首页/推荐输入 | 核心入口 |
| `/recommendation` | 推荐结果页 | 携带 sessionId/结果 |
| `/professor/:id` | 导师详情 | |
| `/chat` | 对话追问 | 携带 sessionId |
| `/favorites` | 收藏 | |
| `/history` | 历史记录 | |
| `/compare` | 导师对比 | V1.0，携带两个 professorId |
| `/settings` | 设置 | |
| `/settings/privacy`、`/settings/terms`、`/settings/about` | 隐私/协议/关于 | V1.0 |
| 反馈 | 以底部 sheet/对话框呈现，不单独占路由 | |

`redirect`：首启未看引导 → `/onboarding`；核心功能**免登录可用**（游客），仅「云同步」类操作引导登录。

---

## 9. 设计语言（方向，实现时细化）

- **Material 3**，亮/暗双主题；学术感种子色：**靛蓝/青绿系**（`ColorScheme.fromSeed`，可调）。
- 卡片圆角、清晰信息层级；`MatchLevelChip`：高=主色实心、中=次级、低=中性；研究方向用 chip 流（`FieldChips`）。
- 完整 加载/空/错 三态视图；中文文案贴合需求 §11。
- 中文排版优先（默认系统字体，必要时再引入字体资源）。
- 重要操作不深藏；用户可随时返回修改条件（需求 §12.3）。

> 视觉细化可在实现阶段配合 UI/UX 设计能力产出 mockup；本文只定方向。

---

## 10. Mock 数据策略

- `data/mock/fixtures/` 内置**真实风格中文假数据**：≥12 位导师（覆盖 AI/CV/NLP/医学影像/机器人/网络安全/生物信息/材料计算等方向，分布北京/上海/江浙沪等），含 bio、研究方向、主页链接、limitations、data_quality_score。
- `MockDb`（内存）：按 prompt 关键词/地域/阶段做**简单匹配打分**，产出 `QueryUnderstanding` + 排序后的 `recommendations` + `followUpQuestions`，让 demo「像真的」。
- 多轮对话：Mock 维护 `sessionId → 上下文`，支持「为什么推荐/相似导师/只看某地/换方向」等意图的合理假回答。
- 场景开关：可注入空结果、弱网延迟、各错误码，用于状态演示与测试。

---

## 11. 对原需求的修正记录（已获授权「完善和修改」）

1. **登录矛盾**（开放问题 Q1 vs §12.3）→ 采用**模拟登录 + 游客模式**：核心功能免登录可用，登录用于解锁云端同步。Q1「必须登录」相应改为此口径。
2. **`minSdk`** → 由 Flutter 默认显式改为 **31**（Android 12，需求 §12.2/§18.2）。
3. **云端同步**（Q4/Q5=是）→ 无后端阶段以 `SyncService` 接口 + 本地实现占位，保证将来可接。
4. **应用内 WebView**（Q8=MVP 不做）→ 教师主页用系统浏览器（`url_launcher`）；空/无效链接按需求 §6.4 提示。
5. **iOS**（Q9）→ 代码平台无关，主测 Android，不保证上架。
6. **导师对比**（Q6=是，但 §15.2 列为暂缓）→ 放入 **V1.0** 的基础双人对比；简历解析/申请规划（Q7）仍不做。

---

## 12. 阶段路线图

| 阶段 | 目标 | spec |
|---|---|---|
| V0.1 原型 | 跑通核心推荐链路（地基 + 输入 → 推荐 → 详情） | `2026-06-07-schonavi-v0.1-prototype-spec.md` |
| V0.2 MVP | 形成可用闭环（登录/对话/收藏/历史/反馈/全套状态/APK） | `2026-06-07-schonavi-v0.2-mvp-spec.md` |
| V1.0 正式 | 面向真实使用 + 接后端就绪（流式/同步/对比/隐私/埋点/监控） | `2026-06-07-schonavi-v1.0-spec.md` |

---

## 13. 全局非功能性验收（需求 §12 / §17）

- 启动 ≤3s 进首页；提交后 ≤1s 出加载态；推荐结果 3–10s（视数据/Mock 延迟）。
- 页面切换无明显卡顿；本地收藏/历史读取 ≤1s。
- 字段缺失页面不异常；接口失败/超时 App 不崩溃且有重试。
- 本地收藏/历史持久化，清除后不再展示。
