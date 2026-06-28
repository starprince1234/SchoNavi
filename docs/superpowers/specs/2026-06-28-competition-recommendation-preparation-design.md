# 竞赛推荐统一与备赛 MVP — 设计文档

- 日期：2026-06-28
- 分支：iter4
- 状态：已通过头脑风暴与代码评审修正，待实现

## 1. 背景与目标

当前竞赛推荐与导师推荐体验割裂：

- 导师推荐在首页原地以"用户消息 → 思考 → 助手摘要 → 横滑卡"呈现，走 `ChatNotifier` 多轮会话。
- 竞赛推荐提交后立即跳转 `/competition-recommendation` 全屏页，使用纵向 Material `Card` 列表，视觉与交互均不一致。
- 无竞赛详情页，无备赛计划能力。

本次目标：

1. 竞赛推荐改为首页原地响应，形态与导师一致，但**不做多轮对话**。
2. 竞赛卡只承担推荐摘要；详细赛制进入竞赛详情页。
3. 详情页通过"开始备赛"创建个人计划；计划基于本地模板生成，AI 仅负责个性化，无 AI 或 AI 失败时自动使用标准模板。

## 2. 关键决策（头脑风暴 + 评审修正）

| 编号 | 决策点 | 选定方案 |
|---|---|---|
| D1 | 首页竞赛原地响应架构 | 折中：抽通用 `SwipeCardCarousel<T>` + 展示模型 `RecommendationCardData`；导师继续走 `ChatNotifier`，竞赛走独立 `CompetitionHomeNotifier`，共用同一套卡片组件 |
| D2 | 思考状态/助手摘要实现 | **异步状态**（idle/loading/result/empty/error），不伪造流式；Notifier 预留 SSE 接入口，未来只替换数据源 |
| D3 | 详情页字段来源 | 目录优先（按 id 查 `competitionCatalog` 权威赛制），AI 返回的 limitations/preparationTips 作为"补充提示" |
| D4 | 备赛计划竞赛快照 | 单一 `CompetitionSnapshot`（name/category + 规则摘要），删除重复字段 |
| D5 | 模板承载形式 | 混合：通用阶段骨架 + 必做任务用 Dart 强类型锁死；类别模板 + 赛事覆盖项用 JSON assets |
| D6 | 模板来源 | **本地打包**，v1 不做远程；设计 `PreparationTemplateProvider` 接口预留远程接入点 |
| D7 | AI 职责边界 | 客户端确定性计算所有阶段/任务日期；AI 只补充可选任务 + 个性化建议，不动必做任务、不动时间 |
| D8 | 任务合并策略 | 合并：标准模板（含必做）为基底，AI 只能追加可选任务 + 建议；未知阶段/重复/超量/非法字段全部丢弃 |
| D9 | 临近压缩排期 | 可用天数 < 阶段数时按顺序合并相邻阶段，每个最终阶段至少 1 天；任务日期 clamp 到 [今天, 目标日期]；总天数 < 阈值时顶部警示但仍生成 |
| D10 | 每周投入预算 | **纳入 v1**：每任务 `estimatedHours`，按每周投入选可选任务，必做超预算时负荷警示 |
| D11 | 表单与档案 | 保留预填（经验等级从 `UserProfile` 预填、不回写）+ 明确提示"AI 模式会发送档案" |
| D12 | HTTP 契约 | spec 定契约 + 同步更新 `api-contract.md`/`openapi.yaml` + `fake_backend.dart` handler |
| D13 | 卡片"开始备赛"入口 | 卡片只放"访问官网"；"开始备赛/继续备赛"统一在详情页 |
| D14 | "我的备赛"列表 | 按计划列；进行中为主，归档默认隐藏 + 筛选可见 |

## 3. 总体架构

三条独立改造线，互不阻塞，可按引擎 → 界面顺序实施：

1. **首页竞赛原地响应**：`CompetitionHomeNotifier`（异步状态机）+ 流式改造的 `CompetitionRecommendationRepository`（返回 `Result`，非流式）+ 泛型 `SwipeCardCarousel<T>` + `RecommendationCardData` 展示模型。
2. **竞赛详情页**：`/competition/:id` 路由 + `CompetitionDetailPage`，目录优先字段 + AI 补充 + 官网入口 + 备赛入口。
3. **备赛计划 MVP**：`PreparationPlan` 聚合根 + `PreparationPlanRepository`（`competition_preparation_plans.v1`）+ 本地模板（Dart + JSON）+ `PreparationPlanGenerator`（本地生成 + AI 个性化 + 兜底）+ 创建表单 + 列表/详情页 + 抽屉入口。

## 4. 数据模型

### 4.1 展示模型（UI 层，领域实体不感知）

```dart
class RecommendationCardData {
  final String id;
  final String title;          // 教授姓名 / 竞赛名称
  final String? subtitle;      // 职称+院系 / 类别+级别
  final List<String> tags;
  final double matchScore;     // 0.0–1.0
  final String reason;         // 青色理由引述
  final String? openUrl;       // 官网（竞赛有，导师可空）
  final RecommendationKind kind; // mentor | competition
}
```

- 匹配等级由 `matchScore` 派生：`≥0.8 high`、`≥0.6 medium`、其余 `low`。`MatchLevelChip` 内部根据 `matchScore` 自行派生等级，外部只传 `matchScore`（保留现有进度弧渲染）。
- `Recommendation`（导师）与 `RecommendedCompetition`（竞赛）各写一个 Mapper → `RecommendationCardData`。点击/收藏/打开官网等回调由组件外传入，不进入展示模型。

### 4.2 备赛计划领域模型

```dart
enum PreparationPlanStatus { active, archived }
enum WeeklyCommitment { hours3to5, hours6to10, hours11to15, hours16plus }
enum ExperienceLevel { beginner, intermediate, experienced }
enum PreparationTaskKind { required, optional, userAdded }

class CompetitionSnapshot {
  final String id;
  final String name;
  final String category;
  final CompetitionRulesSummary rulesSummary; // signupTime, contestTime, teamSize, format, organizer, officialUrl
}

class PreparationPlan {
  final String id;
  final CompetitionSnapshot competition;   // 单一快照，无重复 source* 字段
  final DateTime targetDate;
  final WeeklyCommitment weeklyCommitment;
  final ExperienceLevel experienceLevel;
  final PreparationPlanStatus status;
  final List<PreparationPhase> phases;
  final String? personalizedSummary;       // AI 全局建议
  final DateTime createdAt;
  final DateTime updatedAt;
}

class PreparationPhase {
  final String key;            // 稳定 key，与模板/AI 输出对齐
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final List<PreparationTask> tasks;
  final String? personalizedAdvice;
}

class PreparationTask {
  final String id;
  final String? templateKey;   // 来自模板的稳定 key；userAdded 为 null
  final String title;
  final PreparationTaskKind kind;
  final double estimatedHours; // 预算计算用
  final DateTime dueDate;
  final String? note;
  final DateTime? completedAt; // != null 即已完成
  bool get completed => completedAt != null;
}
```

约束：

- 必做任务（`kind == required`）不可删除，可改备注与完成状态。
- 可选任务（`optional`）与用户任务（`userAdded`）支持完整增删改。
- 同一竞赛最多一个未归档计划；已有则"继续备赛"，归档后才能创建新计划。

### 4.3 通用模板（Dart，强类型锁死）

`lib/data/fixtures/preparation_templates.dart`：

- 通用阶段骨架（建议时长占比，用于排期）：
  1. `team_formation` 组队
  2. `topic_selection` 选题
  3. `proposal_writing` 方案撰写
  4. `submission_polish` 打磨提交
  5. `defense_prep` 答辩准备
- 每阶段的**必做任务**（`required: true`，含 `estimatedHours`），AI 不可删除。
- 按经验等级补基础任务（beginner 在 `team_formation`/`topic_selection` 追加更多基础必做）。
- 这是永久离线兜底，编译期检查。

### 4.4 类别/赛事模板（JSON assets）

- `assets/preparation_templates/category_templates.json`：按 category（计算机类/电子与信息类/理学类/经管类/综合与创业类/语言与艺术类）追加该类别必做 + 可选任务（含 `estimatedHours`）。
- `assets/preparation_templates/competition_overrides.json`：具体赛事覆盖项，复用 `competition_catalog.dart` 已有 `preparationTips` 整理。
- 运行时加载、易扩充、改模板不重编译。
- 加载失败 → 仅使用 Dart 通用模板，不阻断。

### 4.5 模板来源抽象

```dart
abstract class PreparationTemplateProvider {
  Future<PreparationTemplate> load();
}
class LocalPreparationTemplateProvider implements PreparationTemplateProvider { ... }
// 未来：RemotePreparationTemplateProvider（GET /preparation-templates + ETag + cache）—— v1 不实现
```

v1 只实现 `LocalPreparationTemplateProvider`，接口预留远程接入点。

## 5. 首页竞赛原地响应

### 5.1 状态机

`CompetitionHomeNotifier` 状态：`idle | loading | result | empty | error`。

- 提交时进入 `loading`，显示用户消息 + 思考占位。
- 结果到达：`result`（含 understanding + recommendations）→ 渲染助手摘要 + 横滑卡；空 → `empty`；异常 → `error`。
- 取消旧请求 + 请求序号防止过期结果覆盖。
- "调整条件"返回 `idle` 输入态。
- 未来 SSE 只替换数据源与 Notifier 内部消费方式，不改变页面状态与组件接口。

### 5.2 仓库接口

`CompetitionRecommendationRepository.getRecommendations(...)` 保持 `Result<CompetitionRecommendationResult>` 返回（**非流式**）。`AiCompetitionRecommendationRepository` 继续走 `llm.complete(jsonMode: true)` 一次性返回；`HttpCompetitionRecommendationRepository` 走 `POST /api/v1/recommendations/competitions`。思考状态由 Notifier 在 loading 期间用占位呈现，不伪造 delta。

### 5.3 卡片组件

- 抽 `SwipeCardCarousel<T>`（来自 `recommendation_carousel.dart`）：只负责分页、缩放、胶囊指示器、触觉反馈、语义标签、大字体适配；卡片由 `itemBuilder: (data) => Widget` 提供。
- `SwipeRecommendationCard` 改为接受 `RecommendationCardData` + 回调（onTap/onFavorite/onOpenUrl）。
- 竞赛需求理解卡 `CompetitionQueryUnderstandingCard` 改用 `BentoTile` + `_KVRow`，对齐导师版 `QueryUnderstandingCard` 的 AI 标题 + 键值布局。

### 5.4 首页改动

`home_page.dart` `_submit()` 竞赛分支不再 push `/competition-recommendation`，改为驱动 `CompetitionHomeNotifier`，原地渲染。

## 6. 竞赛详情页

- 路由 `/competition/:id` → `CompetitionDetailPage`。
- 字段来源：按 `id` 查 `competitionCatalog` 权威赛制（报名时间/比赛时间/团队规模/形式/主办方/官网/注意事项）；本次推荐结果中的 `limitations`/`preparationTips` 作为"AI 补充提示"独立区块显示，不覆盖目录事实。
- 操作：官网入口、"开始备赛/继续备赛"。
- 推荐卡主体点击 → 进入详情页。

## 7. 备赛计划生成

### 7.1 生成顺序（`PreparationPlanGenerator.generate(...)`）

1. 加载 Dart 通用模板（通用阶段 + 必做任务）。
2. 叠加 JSON 类别模板（同 `key` 阶段追加任务）。
3. 叠加 JSON 赛事覆盖项。
4. 按经验等级补基础任务。
5. 按每周投入预算选可选任务（总 `estimatedHours` 不超预算）；必做工作量超预算时标记负荷警示。
6. AI 个性化（见 7.2）。
7. 客户端确定性排期（见 7.3）。

### 7.2 AI 个性化

- **本地 LLM 模式**：调 `llm.complete(jsonMode: true)`，提示词约束 AI 只返回已知阶段下的可选任务 + 个性化建议：
  `{ phases: [{ key, optionalTasks: [{templateKey?, title, estimatedHours}], personalizedAdvice }], globalAdvice }`
- **HTTP 模式**：`POST /api/v1/preparation-plans/generate`（OpenAPI 路径写作 `/preparation-plans/generate`，server base `/api/v1`）。请求：`{ competition: CompetitionSnapshot, targetDate, weeklyCommitment, experienceLevel, userProfile? }`。响应同上结构。
- **校验合并**：未知阶段、重复 `templateKey`、超量任务、非法字段全部丢弃；合并到标准计划，必做任务永不丢。
- **兜底**：AI 未配置/超时/解析失败 → 直接保存标准模板计划（已含必做 + 客户端算好日期），不将创建流程置为失败。

### 7.3 确定性排期

- 输入：`targetDate`、各阶段建议时长占比、各任务 `estimatedHours`。
- 阶段日期按占比分配 `[今天, targetDate]`；可用天数 < 阶段数时**按顺序合并相邻阶段**，每个最终阶段至少 1 天。
- 任务 `dueDate` clamp 到所属阶段区间且 ∈ [今天, targetDate]。
- 总天数 < 阈值（如 14 天）→ 计划详情顶部显示"时间偏紧"警示，仍允许创建。

### 7.4 计划编辑语义

- 任务完成/撤销：置/清 `completedAt`。
- 添加/编辑/删除/备注：`optional`/`userAdded` 支持完整增删改；`required` 不可删，可改备注与完成。
- 进度 = 已完成任务数 / 总任务数。
- 修改目标日期：仅重新计算未完成任务 `dueDate`，保留完成状态与备注。
- 删除/归档计划：二次确认。

## 8. UI 与路由

- 首页竞赛 tab 提交 → `CompetitionHomeNotifier` 原地渲染 + "调整条件"返回输入态。
- `/competition/:id` → `CompetitionDetailPage`（目录事实 + AI 补充 + 官网 + 备赛入口）。
- 首次"开始备赛" → 设置表单（目标日期必填且晚于当天 / 每周投入 4 档 / 当前水平 3 档；经验等级从 `UserProfile` 预填不回写；提示"AI 模式会发送档案"）→ 生成计划 → 跳计划详情。
- `/preparation-plans` → "我的备赛"列表（按计划列，活动/归档筛选，归档默认隐藏）。
- `/preparation-plans/:id` → 计划详情（倒计时/负荷警示/总进度/当前阶段/阶段时间轴/任务清单）。
- 右侧抽屉 `AppMenuDrawer` 加"我的备赛"入口。
- 保留 `/competition-recommendation` 作为历史/深链入口，复用新组件。

## 9. 数据与接口

- 新增领域类型：`PreparationPlan`、`PreparationPhase`、`PreparationTask`、`CompetitionSnapshot`、`CompetitionRulesSummary`、`PreparationPlanStatus`、`WeeklyCommitment`、`ExperienceLevel`、`PreparationTaskKind`、`PreparationTemplate`、`RecommendationCardData`、`RecommendationKind`。
- 新增 `PreparationPlanRepository`（`LocalStore` key `competition_preparation_plans.v1`）：多计划持久化 + `watch()` Stream + 创建/更新/归档/删除；损坏数据降级忽略。
- 新增 `PreparationPlanGenerator` + `PreparationTemplateProvider`（v1 仅 `LocalPreparationTemplateProvider`）。
- 新增 `CompetitionHomeNotifier`（Riverpod）。
- HTTP 契约：`POST /api/v1/preparation-plans/generate`，同步更新 `docs/api-contract.md`、`docs/openapi.yaml`，并在 `lib/data/mock/fake_backend.dart` 注册 handler。
- AI 不得生成/修改官方比赛日期，不得删除模板必做任务；计划保存 `CompetitionSnapshot` 避免目录更新导致已有计划变化。

## 10. 测试计划

- 首页竞赛原地：loading/result/empty/error/重新筛选 + 异步竞态取消（过期结果不覆盖）。
- 展示模型：`Recommendation`/`RecommendedCompetition` → `RecommendationCardData` Mapper 正确性；匹配等级派生。
- 横滑卡：分页、语义标签、44px 触控、长文本/大字体不溢出。
- 详情页：目录事实优先，AI 字段仅作补充。
- 计划生成：不同时间跨度/水平/投入档位；临近压缩（合并相邻阶段）；投入预算选可选任务 + 负荷警示。
- 模板合并：通用 + 类别 + 赛事覆盖叠加正确；JSON 加载失败降级到 Dart 通用模板。
- AI 兜底：正常/未配置/超时/畸形结果均生成可用计划且必做任务不丢；未知阶段/重复/超量/非法字段丢弃。
- 持久化：序列化、损坏数据降级、任务编辑、完成度、目标日期调整重排（保留完成+备注）、归档、"继续备赛"判定。
- 验证 `flutter analyze`、全量 `flutter test`、浅色/深色、375px 宽度、大字体模式。

## 11. Assumptions

- 第一版不实现竞赛多轮对话与 SSE，只保留替换空间。
- 不包含团队协作、账号同步、系统通知、日历同步、云端计划同步。
- 远程模板更新不需发版，但 v1 不实现远程；模板 schema 变化仍需客户端升级。
- 倒计时只使用用户确认的目标日期；赛事目录中自然语言时间仅供参考。
- 沿用现有 slate/indigo/cyan 冷调视觉系统，不引入竞赛专属配色。
