# SchoNavi 功能梳理（截至 2026-07-02）

> 面向项目经理、研发协作和验收沟通。按“用户价值 / 实现要点 / 质量保障”组织，重点同步当前 App 已有功能，以及 Android 原生能力接入后对备赛体验的补强。

## 一、项目定位

SchoNavi 是一款面向高校学生的 AI 辅助学业与竞赛导航 Flutter 应用。核心能力是把“找导师”“选竞赛”“备赛执行”三件信息密集型任务串成可对话、可追溯、可落地的链路：

- 输入研究兴趣或升学目标 → 对话式追问 → 推荐导师卡片 → 详情证据 → 匹配分析 / 套磁邮件 / 导师对比。
- 输入竞赛意向 → 推荐竞赛 → 创建个性化备赛计划 → 智能日历 → AI 助手提出改动卡 → 用户确认后落地。
- 备赛计划同步到 Android 桌面小组件、系统日历和通知提醒，让计划从 App 内管理扩展到系统级触达。

技术栈：Flutter + Riverpod + GoRouter + Dio + SharedPreferences + Flutter Secure Storage + DeepSeek/OpenAI 兼容 LLM 客户端 + Android Kotlin 原生桥接。架构分层保持为 features（UI）→ domain（实体与 repository 接口）→ data（mock / local / HTTP / AI 实现）→ core（配置、DI、路由、主题、AI 客户端、平台能力）。

## 二、功能全景

| 模块 | 用户价值 | 是否含 LLM | 主要入口 |
|---|---|---|---|
| 首页 | 统一承接找导师 / 找竞赛，两类需求自然语言启动 | 是 | /home |
| 对话式导师推荐 | 自然语言找导师、追问、推荐卡片 | 是 | /recommendation、/chat |
| 导师详情 | 查看研究方向、推荐理由、数据来源 | 否 | /professor/:id |
| 匹配分析 | 学生档案 vs 导师事实的维度分析 | 是 | /match |
| 套磁邮件 | 根据导师事实和学生背景生成草稿 | 是 | /email |
| 导师对比 | 2-3 位导师横向比较 | 是 | /compare |
| 竞赛推荐 | 根据兴趣、专业、投入时间推荐竞赛 | 是 | /competition-recommendation、/competition/:id |
| 备赛计划 | 生成分阶段任务、倒计时、智能日历 | 是 | /preparation-plans、/preparation-plans/new、/preparation-plans/:id |
| 备赛 AI 助手 | 自然语言调整计划，输出改动卡 | 是 | 计划详情页抽屉 |
| Android 小组件 | 桌面查看倒计时、进度、阶段和下一任务 | 否 | 备赛列表右上角 / 系统桌面 |
| 系统日历 | 将报名截止、提交截止、比赛开始加入日历 | 否 | 计划详情页截止卡片 |
| Android 通知 | 任务提醒、摘要、截止提醒、通知动作 | 否 | Android 通知栏 |
| 个人档案 | 驱动推荐、匹配、邮件和计划个性化 | 部分 | /profile、/profile/wizard |
| 收藏 / 历史 | 管理导师候选池，回看对话和搜索 | 否 | /favorites、/history |
| 反馈 | 对回复和推荐卡片提交质量反馈 | 否 | 对话气泡 / 推荐卡片 |
| 设置 | 查看数据源、模型、服务状态和演示配置 | 否 | /settings |
| 引导与启动 | 首启介绍、启动页和 App 壳层 | 否 | /onboarding、/ |

## 三、各功能模块详解

### 1. 首页：双 Tab 统一入口

- 用户视角：进入 App 即看到统一输入框，通过“找导师 / 找竞赛”切换意图。用户直接描述目标，系统原地响应。
- 实现要点：lib/features/home/pages/home_page.dart 负责首页体验；竞赛 Tab 由 CompetitionHomeNotifier 管理 idle/loading/result/empty/error 状态；对话式结果与推荐卡片复用聊天组件。
- 体验价值：减少“先选功能、再填筛选器”的启动成本，让用户先表达目标。

### 2. 对话式导师推荐

- 用户视角：输入研究兴趣、学校偏好、背景条件后，系统生成推荐卡片；用户可继续追问、换方向、要更多导师或查看详情。
- 实现要点：
  - lib/features/recommendation/：推荐页、意图理解卡、推荐结果展示。
  - lib/features/chat/：对话流、推荐卡片、追问、反馈、重试等交互。
  - 推荐需求分类由 LLM / 本地规则共同支持，判断“更多导师 / 同领域 / 换方向 / 细节追问”等意图。
  - Fork 式追问会话用于围绕某位导师继续讨论，避免主会话上下文被污染。
- 体验价值：用户可以从推荐列表自然进入追问，而不是每次重新发起搜索。

### 3. 导师详情、匹配分析、套磁邮件和对比

- 导师详情：lib/features/professor/ 展示导师主页、研究方向、简介、推荐依据和数据来源。
- 匹配分析：lib/features/match/ 基于导师事实和用户档案生成维度分析，明确不预测录取概率。
- 套磁邮件：lib/features/email/ 使用结构化 LLM 输出邮件主题和正文，定位为可编辑草稿。
- 导师对比：lib/features/compare/ 支持 2-3 位导师的横向 Markdown 报告。
- 体验价值：把“推荐名单”推进到“判断、比较、准备联系材料”的行动阶段。

### 4. 竞赛推荐与详情

- 用户视角：描述兴趣、专业、年级、基础和可投入时间，获得竞赛推荐；进入详情后查看规则摘要、时间节点、赛制、主办方、官方链接，并可创建备赛计划。
- 实现要点：
  - lib/features/competition_recommendation/ 处理竞赛推荐页、竞赛详情和首页竞赛结果。
  - 本地竞赛事实库位于 lib/data/fixtures/competition_catalog.dart，配合 docs/竞赛助手/ 规则文档沉淀。
- 体验价值：推荐结果不是终点，而是备赛计划入口。

### 5. 个性化备赛计划

- 用户视角：选定竞赛后填写目标日期、报名截止、每周投入、经验等级和时间模型，生成分阶段任务计划。
- 实现要点：
  - lib/domain/services/preparation_plan_generator.dart：模板 → 经验补基础 → 预算选可选 → AI 个性化合并 → 排期 → 组装。
  - assets/preparation_templates/category_templates.json：通用赛类模板。
  - assets/preparation_templates/competition_overrides.json：具体赛事覆盖。
  - 提交型 / 窗口型竞赛使用不同时间组织方式。
  - AI 个性化失败时保留模板兜底，必做任务不丢。
- 体验价值：计划既能个性化，又不会因为 AI 不稳定导致核心任务缺失。

### 6. 备赛计划详情

- 用户视角：查看倒计时、报名截止、提交截止或比赛开始、阶段时间线、任务清单和个性化建议。
- 已支持操作：
  - 勾选任务完成。
  - 编辑用户自定义任务。
  - 添加用户任务。
  - 删除可删除任务。
  - 调整目标日期并重排未完成任务。
  - 编辑报名截止。
  - 归档或删除计划。
  - 将关键日期加入系统日历。
- 实现要点：lib/features/preparation/pages/preparation_plan_detail_page.dart 负责详情页，lib/features/preparation/widgets/ 拆分倒计时、阶段轴、任务列表、截止卡片和助手抽屉。
- 体验价值：详情页承担深度管理，小组件和通知承担日常触达。

### 7. 备赛 AI 助手

- 用户视角：在计划详情页打开助手抽屉，输入“降低下周任务量”“加一次模拟答辩”等自然语言请求。
- 实现要点：
  - lib/features/preparation/providers/preparation_assistant_controller.dart 管理按计划维度的助手状态。
  - LLM / HTTP / Fake 三套实现共用 DTO 解码和改动校验。
  - lib/domain/services/plan_change_validator.dart 校验改动卡。
  - lib/domain/services/plan_change_applier.dart 原子应用用户接受的卡片。
  - 助手历史按计划持久化，关闭抽屉不取消在途请求。
- 体验价值：AI 不直接篡改计划，而是提出可审批的结构化变更。

## 四、Android 原生能力层

Android 原生能力的核心设计是：Flutter 侧仍然管理计划和业务状态，Android 侧接收精简后的备赛快照，负责系统桌面、通知、闹钟和日历。

### 1. 平台桥接

- Flutter 接口：lib/core/platform/preparation_reminder_platform.dart
- MethodChannel：com.example.scho_navi/preparation_reminders
- 支持方法：
  - syncSnapshot：同步备赛快照给 Android。
  - updateSchedule：更新提醒偏好。
  - getNotificationStatus / requestNotificationPermission：查询或请求通知权限。
  - pinWidget：请求系统添加桌面小组件。
  - addDeadlineEvent：写入或打开系统日历事件。
  - openNotificationSettings：打开系统通知设置。
  - takeInitialRoute / openRoute：处理原生入口回跳。

### 2. 备赛提醒快照

- 实体：lib/domain/entities/preparation_reminder.dart
- 构建器：lib/domain/services/preparation_reminder_builder.dart
- 当前 schemaVersion：3
- 主要字段：
  - 计划摘要：竞赛名、目标日期、当前阶段、完成任务数、总任务数。
  - 阶段摘要：最多用于小组件阶段轴显示 completed / active / upcoming。
  - 待办任务：用于每日任务通知和通知动作。
  - 截止提醒：截止前 7 天、3 天、当天。
  - 连续推进状态：用于小组件展示 streak。

### 3. 桌面小组件

- Android 入口：android/app/src/main/kotlin/com/example/scho_navi/PreparationWidgetProvider.kt
- 资源：android/app/src/main/res/layout/preparation_widget_micro.xml、small、wide、hero
- 配置：android/app/src/main/res/xml/preparation_widget_info.xml
- 能力：
  - 四档尺寸自适应：Micro、Small、Wide、Hero。
  - 展示 D-Day、当前阶段、下一项任务、完成进度、连续推进状态。
  - Hero 档展示阶段轴。
  - 多计划时由 WidgetRotationScheduler 每 30 秒轮换展示。
  - 点击跳转 /preparation-plans/{planId}。
  - 明暗模式使用不同资源调色。
- 体验判断：小组件只做概览和回流，不承载复杂编辑，避免桌面 RemoteViews 限制导致交互复杂化。

### 4. 系统日历

- Flutter 入口：计划详情页的 PreparationDeadlineCard。
- Android 实现：MainActivity.addDeadlineEvent。
- 能力：
  - 写入全天事件：标题为“竞赛名·节点名”，备注为 SchoNavi 来源。
  - 没有权限或写入失败时，fallback 到系统日历 App 的插入事件 intent。
  - 使用 ISO 日字符串跨 Flutter / Android 边界传递，降低时区漂移风险。
- 覆盖节点：报名截止、提交截止、比赛开始。

### 5. 通知、闹钟与通知动作

- 通知工厂：android/app/src/main/kotlin/com/example/scho_navi/ReminderNotificationFactory.kt
- 每日提醒：ReminderScheduler + DailyReminderReceiver
- 截止提醒：DeadlineAlarmScheduler + DeadlineAlarmReceiver
- 通知动作：ReminderActionReceiver + NotificationActionCoordinator
- 能力：
  - 备赛任务通知：完成此任务 / 稍后提醒 / 查看计划。
  - 今日摘要：今天剩余任务、最近截止、未来 30 天截止数。
  - 截止提醒：截止前 7 / 3 / 0 天。
  - “完成此任务”动作可通过 UI Channel 或 Headless Flutter Engine 调用 Dart 用例，更新本地计划后刷新快照、小组件和提醒。
  - “稍后提醒”通过 AlarmManager 延后一小时触达。
  - BOOT_COMPLETED、应用更新、时区变化、日期变化后重新调度。
- 体验判断：通知动作解决“看到提醒后还要打开 App 找任务”的摩擦；深度编辑仍回到计划详情。

## 五、个人档案、收藏、历史、反馈与设置

### 1. 个人档案

- 位置：lib/features/profile/
- 能力：基础信息、成绩排名、研究兴趣、竞赛经历、科研经历、隐私说明、分步向导、档案完成度。
- 用途：导师推荐、匹配分析、套磁邮件和备赛计划个性化。

### 2. 收藏和历史

- 收藏：lib/features/favorite/，用于管理导师候选池。
- 历史：lib/features/history/，用于回看搜索和会话上下文。

### 3. 反馈

- 位置：lib/features/feedback/ 和聊天组件中的反馈入口。
- 能力：对 AI 回复、推荐卡片等提交反馈，保留上下文信息。
- 用途：为后续推荐策略、事实库和提示词优化留下可追踪记录。

### 4. 设置

- 位置：lib/features/settings/
- 能力：展示当前服务和模型配置，支持演示时观察数据源与 AI 相关配置。

## 六、底层能力

### 1. 数据源切换

领域 repository 保持接口隔离，按配置切换实现：

- mock：固定假数据，用于离线演示与测试。
- local：基于 SharedPreferences / SecureStorage 的本地持久化。
- HTTP：对接外部 FastAPI 后端。
- AI：客户端直连 DeepSeek/OpenAI 兼容 LLM 接口。

### 2. LLM 客户端

- lib/core/ai/deepseek_llm_client.dart：支持 JSON mode、temperature 和流式。
- missing_llm_client.dart：未配置 key 时显式失败，不静默伪造 AI 结果。
- llm_trace.dart：演示模式记录 AI 调用快照。
- 配置通过 Dart define / 环境变量传入，不提交真实密钥。

### 3. 本地持久化

- LocalStore 统一抽象本地键值与 JSON 存取。
- 典型实现：会话、备赛计划、助手历史、水平诊断、收藏、历史、个人档案和提醒偏好。

### 4. 后端边界

后端在独立仓库，不属于当前 Flutter 仓库。当前仓库不应重新引入 web/backend 或 web/backend_agent 目录。

当前 Flutter 仓库保留的权威接口材料：

- docs/api-contract.md
- docs/openapi.yaml
- DEPLOYMENT.md

## 七、质量保障

- 当前 test/ 下有 199 个 Dart 测试文件。
- Android 原生能力相关测试覆盖：
  - test/android_manifest_test.dart：Manifest、receiver、widget 资源等集成断言。
  - test/core/platform/calendar_deadline_event_test.dart：系统日历事件桥接。
  - test/core/platform/notification_action_channel_test.dart：通知动作通道。
  - test/main_notification_action_test.dart：通知动作入口。
  - test/domain/services/preparation_reminder_builder_test.dart：提醒快照、阶段、截止提醒。
  - test/data/local/preparation_reminder_store_test.dart：提醒快照和偏好持久化。
  - test/features/preparation/pages/preparation_plans_page_test.dart：小组件入口。
  - test/features/preparation/pages/preparation_plan_detail_page_test.dart：日历入口。
- Flutter 变更建议最小验证：
  - 相关 widget / provider / domain 测试。
  - flutter analyze。
  - UI 或 Android 原生体验改动需要实机或模拟器人工验证。

## 八、当前状态与下一步

### 已完成

- 导师推荐全链路：推荐、追问、详情、匹配、邮件、对比、收藏、历史。
- 竞赛推荐全链路：推荐、详情、创建备赛计划。
- 备赛计划：模板生成、AI 个性化、水平诊断、双时间模型、任务管理、目标日期重排。
- 备赛 AI 助手：改动卡、校验、用户确认、历史持久化。
- Android 原生增强：小组件、系统日历、通知/截止提醒、原生入口回跳。
- 反馈能力：对回复和推荐结果记录用户反馈。

### 建议后续

- 将通知权限、每日提醒开关和提醒时间在 UI 中更显性化，补齐“用户主动配置”体验。
- 针对 Android 小组件做实机视觉验收：不同启动器、不同尺寸、明暗模式、字体缩放。
- 增强日历写入的重复事件提示或幂等策略，减少用户重复点击导致的重复日程。
- 将后端真实数据接入状态与 App 演示模式做更清晰的可视化区分。
- 继续完善竞赛模板和赛事覆盖，提升计划生成的事实基础。
