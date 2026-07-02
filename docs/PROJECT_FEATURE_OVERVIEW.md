# SchoNavi 功能梳理（截至 2026-06-30）

> 面向项目经理的功能盘点。按"用户能做什么 / 背后怎么实现 / 质量保障"三层组织，可独立分发。

## 一、项目定位

SchoNavi 是一款面向高校学生的 **AI 辅助学业与竞赛导航** Flutter 应用。核心能力是用大模型把"找导师""选竞赛""备赛"这三件大学生高频但信息分散的事，做成一条可对话、可追溯、可落地的链路：

- 输入研究兴趣 / 目标 → 对话式追问 → 推荐导师卡片 → 生成套磁邮件 / 对比 / 匹配分析
- 输入竞赛意向 → 推荐竞赛 → 生成个性化备赛计划 → 智能日历 + AI 助手按需调整日历

技术栈：Flutter + Riverpod 3 + GoRouter + SharedPreferences（本地持久化）+ Dio + DeepSeek/OpenAI 兼容 LLM 客户端。架构分层清晰：`features`（UI）→ `domain`（实体与 repository 接口）→ `data`（mock / 本地 / HTTP / LLM 四套实现）→ `core`（配置、DI、路由、主题、AI 客户端）。

## 二、功能全景

| 模块 | 用户价值 | 是否含 LLM | 路由 |
|---|---|---|---|
| 首页 | 统一入口，双 Tab（导师 / 竞赛）原地响应 | 是 | `/home` |
| 对话式导师推荐 | 自然语言找导师，追问产卡 | 是 | `/recommendation`、`/chat` |
| 导师详情 | 查看推荐理由、研究方向、数据来源 | — | `/professor/:id` |
| 匹配分析 | 学生 vs 导师雷达图 | 是 | `/match` |
| 套磁邮件 | 据导师+背景生成邮件草稿 | 是 | `/email` |
| 导师对比 | 2-3 位导师横向对比报告 | 是 | `/compare` |
| 竞赛推荐 | 自然语言推荐竞赛 | 是 | `/competition-recommendation`、`/competition/:id` |
| 备赛计划 | AI 个性化生成计划+智能日历 | 是 | `/preparation-plans`、`/preparation-plans/new`、`/preparation-plans/:id` |
| 备赛 AI 助手 | 按需唤出改日历，改动卡 accept/decline | 是 | 计划详情页抽屉 |
| 个人档案 | 背景画像，驱动个性化 | 部分 | `/profile`、`/profile/wizard`、`/profile/intro`、`/profile/privacy` |
| 收藏 / 历史 | 收藏导师、查看会话历史 | — | `/favorites`、`/history` |
| 设置 | 切换数据源（mock/LLM）、AI 追踪开关 | — | `/settings` |
| 引导 | 首启引导三屏 | — | `/onboarding` |

## 三、各功能模块详解

### 1. 首页（双 Tab 统一入口）
- **用户视角**：进入 App 即看到一个输入框 + 滑动胶囊切换「找导师 / 找竞赛」。输入后原地展开对话流和推荐卡片，无需跳页。
- **实现要点**：`lib/features/home/pages/home_page.dart`。Tab 切换不清空输入；竞赛 Tab 由 `CompetitionHomeNotifier` 管理 idle/loading/result/empty/error 状态，带请求序号防竞态。副标题用打字机动效。
- **亮点**：把原本分散的导师推荐和竞赛推荐收敛到一个入口，降低用户认知成本。

### 2. 对话式导师推荐（核心链路）
- **用户视角**：输入"我想做计算机视觉方向，想去 985"→ 系统先理解意图（QueryUnderstanding 卡）→ 追问或直接产卡 → 横滑卡片展示推荐导师，每张卡有匹配等级和推荐理由 → 点卡片进详情，或在卡片上继续追问。
- **实现要点**：
  - `lib/features/recommendation/` — 推荐页与意图理解卡。
  - `lib/features/chat/` — 对话页，`ChatNotifier`（`autoDispose.family`）维护会话状态机：`creating/classifying/connecting/streaming/recomminding/committing` 等 14 种活动态。
  - **Fork 式追问会话**：在某个导师下继续追问时，采用 copy-on-fork 分支，主会话不被污染；带 sticky 教授锚点条，让用户始终知道当前追问锚定在哪位导师。
  - **追问路由**：`lib/data/ai/llm_recommendation_need_classifier.dart` + `lib/shared/utils/recommendation_need_classifier.dart`，判断用户是在要"更多导师 / 同领域 / 换方向 / 细节追问"。
  - `seedContext` 衔接 `sessionId`，保证对话上下文连续。
- **数据源**：LLM 模式本地调 DeepSeek 兼容接口；HTTP 模式调后端 `/recommendations/mentors`、`/chat/route` 等。
- **测试**：14 个 chat 测试文件 + 4 个 recommendation 测试文件。

### 3. 导师详情
- **用户视角**：分块展示导师主页、研究方向、简介、数据来源；底部 action 区可"生成套磁邮件""匹配分析"；支持收藏。
- **实现要点**：`lib/features/professor/pages/professor_page.dart`，用 Bento 网格分块。强调"数据来源"可查，呼应"推荐更有依据"的产品卖点。从 fork 追问入口可带 `mainSessionId`/`sourceTurnId` 便于回到原会话。

### 4. 匹配分析
- **用户视角**：选定导师后，基于学生背景 + 导师事实生成匹配雷达图与维度分析，**不预测录取概率**（明确信息性匹配）。
- **实现要点**：`lib/features/match/`，`MatchAnalysisRepository.analyze(professor, profile)`。AI 实现 `lib/data/ai/ai_match_analysis_repository.dart`。无档案时引导去填档案。

### 5. 套磁邮件生成
- **用户视角**：据【导师事实】+【学生背景】一键生成邮件主题与正文草稿，可编辑后复制。
- **实现要点**：`lib/features/email/`，`AiOutreachEmailRepository` 用 LLM `jsonMode` 输出结构化 `{subject, body}`。

### 6. 导师对比
- **用户视角**：选 2-3 位导师，生成横向对比报告（Markdown 渲染）。
- **实现要点**：`lib/features/compare/`，`AiComparisonRepository` 调 LLM 对多位导师做对比，`gpt_markdown` 渲染结果。

### 7. 竞赛推荐 + 详情
- **用户视角**：首页竞赛 Tab 输入意向 → 推荐竞赛卡片 → 点进详情看规则摘要、报名时间、赛制、官方链接，并可直接"创建备赛计划"。
- **实现要点**：`lib/features/competition_recommendation/`，竞赛目录来自 `lib/data/fixtures/competition_catalog.dart`（本地事实库，保证推荐可追溯）。`competition_home_notifier` 原地响应、写历史。

### 8. 备赛计划（AI 个性化生成 + 智能日历）— 本期主线
- **用户视角**：选定竞赛 → 填表单（目标日期、每周投入、经验等级、时间模型）→ AI 生成个性化备赛计划，含分阶段任务、可选任务建议、预算排期 → 进详情页看智能日历、阶段时间线、任务清单、倒计时。
- **实现要点**：
  - **生成器**：`lib/domain/services/preparation_plan_generator.dart`，流水线 = 模板 → 经验补基础（beginner 加额外必做任务）→ 预算选可选 → AI 个性化合并 → 排期 → 组装。**AI 失败兜底返回标准模板计划，必做任务始终保留**。
  - **双段时间模型**：区分「提交型」（作品提交到 DDL，`defense_prep` 阶段独立）与「窗口型」（比赛集中在几天）。改目标日期重排时，提交型仅重排前置阶段、`defense_prep` 原样保留。
  - **AI 个性化器**：`lib/data/ai/ai_preparation_personalizer.dart`，约束 LLM 只返回已知 phaseKey 下的可选任务，纯 JSON，客户端解析校验。
  - **水平诊断**：向导 Step2 可让 AI 诊断用户水平画像，结果落盘 `LevelDiagnosisStore`。
  - **模板资产**：`assets/preparation_templates/category_templates.json`（6 大赛类模板）+ `competition_overrides.json`（具体赛事覆盖，如 ICPC）。
- **测试**：12 个 preparation 测试文件，覆盖提交型重排不变量、预算、兜底等。

### 9. 备赛 AI 助手（按需唤出改日历）— AIGC 主攻点
- **用户视角**：在计划详情页从底部抽屉唤出 AI 助手，用自然语言说"把组队阶段往后挪一周""加一个模拟答辩任务"→ AI 返回**改动卡**（move/add/delete/reschedule/appendAdvice 五种）→ 用户**逐张 accept / decline**，接受后才落到计划。
- **实现要点**：
  - `lib/features/preparation/providers/preparation_assistant_controller.dart`：非 autoDispose Notifier，**关闭抽屉不取消在途请求**，按 `planId` 家族化。提供 `send / acceptCard / declineCard / clearContext`。
  - **乐观显示 + request_id 端到端**：每轮请求带 `request_id`，失败 turn 也落盘便于重开看到失败轮；UI 先乐观显示用户消息。
  - **改动卡校验**：`lib/domain/services/plan_change_validator.dart` 标记越界/非法卡为 `rejected`；`plan_change_applier.dart` 原子应用 accept 的卡。
  - **三实现**：LLM / HTTP / Fake 三套助手实现共用 decode + validator。
  - 助手历史独立 `AssistantHistoryStore` 持久化（每计划最近若干轮）。
- **亮点**：把"AI 改日历"做成"提议—审批—落地"的人机协作闭环，而非 AI 直接改，兼顾效率与可控。这是本项目在"大模型应用能力"评分维度上的主攻产出。

### 10. 个人档案（个性化引擎）
- **用户视角**：填基础信息（学校、专业、阶段、GPA、排名）、研究兴趣、竞赛、科研经历 → 完成度进度环 → 用于推荐 / 套磁 / 匹配 / 备赛个性化。
- **实现要点**：`lib/features/profile/`，含隐私协议页、引导页、分步向导（`ProfileWizardPage`）。`UserProfile` 实体 7 项命中率算完成度。支持 AI 抽取科研成就（`achievements_extraction_provider`）。

### 11. 收藏 / 历史
- **收藏**：`/favorites`，支持多选批量操作。
- **历史**：`/history`，会话历史统一从 `conversation/sessions` 派生，折叠展开 v3。

### 12. 设置
- 切换数据源（mock / LLM / HTTP）——评委现场可在 mock 与 AI 间切换做演示。
- AI 追踪开关（演示模式：记录并展示 AI 调用快照）。

### 13. 引导与启动
- **首启引导**：`/onboarding` 三屏可滑动介绍卖点 + 圆点指示 + 跳过，写 `seenOnboarding` 后进首页。
- **启动壳**：`lib/main.dart` 用 dart-define 解析 LLM 配置；`lib/app.dart` 配 MaterialApp.router + 主题 + 回弹滚动。

## 四、底层能力

### 数据源切换（同一套接口，四套实现）
每个领域 repository 都有 `mock / local / http / ai` 四套实现，由 `appConfigProvider.dataSource` 在运行时切换：
- **mock**：固定假数据，离线演示与测试用。
- **local**：基于 LocalStore 的 SharedPreferences 持久化，敏感配置使用 SecureStorage。
- **http**：调 FastAPI 后端（`lib/data/http/`）。
- **ai**：本地直连 LLM（`lib/data/ai/`）。

> 这意味着 App 可在"纯离线 mock""本地 LLM""接后端"三种模式下运行，便于演示、测试与渐进上线。

### LLM 客户端
- `lib/core/ai/deepseek_llm_client.dart`：DeepSeek/OpenAI 兼容，支持 `jsonMode`、`temperature`、流式。
- `missing_llm_client.dart`：未配置 key 时显式失败，**不静默回退**。
- `llm_trace.dart`：演示模式记录 AI 调用快照。
- 配置走 dart-define（`LLM_API_KEY` / `LLM_BASE_URL` / `LLM_MODEL`），不落库不入仓。

### 本地持久化
- `LocalStore` 统一抽象本地键值与 JSON 存取，`SharedPreferencesLocalStore` 提供运行时实现。
- `LocalConversationRepository`、`LocalPreparationPlanRepository`、`LevelDiagnosisStore`、`AssistantHistoryStore`、`LocalFavoriteRepository`、`LocalHistoryRepository`、`LocalProfileRepository` 等按域拆分。
- `flutter_secure_storage` 存敏感项；`shared_preferences` 存偏好。

### 后端
- **`web/backend`**（FastAPI 适配层）：`routes.py` 暴露 `/recommendations`、`/professors/{id}`、`/chat/messages`、`/preparation-plans/{id}/assistant` 等，对接 `agent_adapter`。
- **`web/backend_agent`**（Python 推荐引擎）：完整的图 + 向量索引 + LLM 推荐管线，含 `recommendation_service` / `ranking_service` / `reranker_service` / `evidence_assembler` / `explanation_service` / `graph_service`，以及 `build_graph` / `build_vector_index` / `import_dataset` 等离线任务。带 admin / feedback / graph / items / recommend / users 等 v1 路由。
- **API 契约**：`docs/api-contract.md` + `docs/openapi.yaml` 完整定义所有端点（identity、chat sessions/turns/forks、recommendations、professors、compare、match-analysis、outreach-email、profile、favorites、history、preparation-plans generate/diagnose/assistant）。

## 五、质量保障

- **测试规模**：182 个测试文件。按层分布：data 50、core 25、shared 16、domain 14；按功能：chat 14、profile 13、preparation 12、competition_recommendation 11、recommendation 4、match 3、home 3、email 3、compare 3，其余 1-2。
- **验证约定**：改 UI 必跑相关 widget 测试 + `flutter analyze`；后端 agent 用 `pytest -m "not realdata"`。

## 六、设计文档沉淀

`docs/superpowers/specs/` 与 `plans/` 沉淀了 22 个 spec + 25 个 plan，覆盖 M1-M6 LLM 核心、流式、套磁邮件、对比、匹配、首页动效、个人档案个性化、对话式推荐、fork 会话、备赛计划、智能日历 AI 助手、助手会话优化等。每个功能都先设计后实现，可追溯。

`docs/竞赛助手/` 沉淀了完整的竞赛规则文档库（工学/理学/计算机/电子与信息/经管/综合与创业/医学与生命科学/数学建模专题/机器人与人工智能 9 个类目规则 + 备赛方法指南 + 备赛流程 + 常见问题 + 网站及工具 + 答辩问题库 + 竞赛信息总览 + README 索引），是备赛推荐与计划生成的事实基底。

## 七、当前状态与下一步

- **已完成**：导师推荐全链路、对话式追问 + fork 会话、竞赛推荐、备赛计划 AI 个性化生成、智能日历双段模型、AI 助手改动卡闭环、个人档案个性化引擎，三模式可切换。
- **AIGC 评分短板**：大模型应用能力（参赛评分四维度之一）此前为 0，本期通过"备赛 AI 助手 + 个性化生成 + 水平诊断 + 对话式推荐"补齐主攻产出。
- **可继续方向**：后端 agent 的向量索引与真实数据接入（目前 mock 为主）、更多竞赛类目模板、备赛助手多轮记忆增强。
