# SchoNavi 增强方案设计 · Bento 视觉重塑 + 旗舰功能 + 移动交互 + 完成度收尾

- 版本：v1（2026-06-10，首稿——实现前可再细化）
- 关系：建立在 **M1–M5（均已实现并 commit）** 之上；**并入 M6 spec**（`2026-06-09-schonavi-m6-polish-narrative-design.md`）的「演示/讲解模式（`LlmTrace`/`showAiTrace`）、设置页、引导/Splash、APK、作品说明」；**取代 M6 §2.4 的视觉方案**（靛蓝/青绿学术色 → 本 spec 的 Bento 暖编辑识别系统）。
- 前置：M1–M5 已落地（推荐/需求理解/详情/流式追问/套磁邮件/对比/匹配分析/收藏/历史）；DeepSeek key 冒烟：`flutter run --dart-define=LLM_API_KEY=...`。
- 开发约定：见仓库既有分层与 Riverpod 3.2.1 手写 provider、Mock/Result、TDD 习惯（不在此重复）。

---

## 1. 目标与策略

冲刺 **AIGC 创新赛**四项评分：创新性（选题/功能/**界面/交互**）、应用价值、作品完成度、大模型应用能力。M1–M5 已让「大模型应用能力」落地为真实生成；本轮把最大短板——**界面惊艳度、记忆点、完成度、移动端交互**——补齐。

- **交付形态**：录屏视频 + 作品说明文档（非现场真机）。因此优先**镜头表现力与叙事**；真实 API 录制，mock 仅作开发与断网兜底。
- **节奏**：3–4 周。
- **总体策略（B）**：强视觉识别 + 一条**旗舰功能轨** + 完成度收尾。

**交付分层（贯穿全文）**

| 层级 | 内容 | 说明 |
|---|---|---|
| **必交核心** | Phase 0 视觉&交互地基 · Phase 1 旗舰① · Phase 2 完成度(M6) · Phase 6 打磨/脚本 | 一定交付，已覆盖三大短板 |
| **Target** | Phase 3 旗舰②（申请军师） | 强目标，时间允许即做 |
| **Stretch** | Phase 4 旗舰③（可解释）· Phase 5 旗舰④（套磁预演） | 加性、可独立丢弃而不影响演示 |

---

## 2. 范围

**In**：Bento 视觉识别系统；移动端触控交互系统；旗舰功能 ①②③④（按序）；M6 完成度（设置/引导/讲解模式/三态/APK/作品说明）。

**Out / 非目标**：
- 语音输入 / 语音对话——**本轮明确不做**，移入 §12 Backlog，全部完成后再回看。
- 录取概率预测——延续 M5 非目标，仅做**信息性**契合分析，不打包票。
- 模拟真实导师"本人观点"——④ 套磁预演仅为**基于公开研究信息的练习模拟**，显式声明非本人立场。
- HTTP 数据源 / 后端 / 账号体系——留 V1.0（`DataSource.http` 仍抛 `UnimplementedError`）。
- 真实导师库爬取——延续现状：mock 事实 + AI 接地生成，事实以 mock 为准并标注"仅供参考"。

---

## 3. 视觉识别系统（Bento · 克制）

落到 `core/theme/app_theme.dart`（重写）+ `pubspec.yaml` 字体资源 + `shared/widgets` 组件主题。

### 3.1 色彩 tokens（克制：墨 + 奶油 + 珊瑚，柠檬黄仅大数字）
| Token | 值 | 用途 |
|---|---|---|
| Ink 墨黑 | `#1A1814` | 文字、描边、英雄磁贴底、主按钮 |
| Paper 奶油底 | `#FBF8F1` | 应用背景 |
| Panel 浅面板 | `#F3EFE4` | 次级磁贴/输入底 |
| Surface 白 | `#FFFFFF` | 卡片磁贴 |
| Coral 珊瑚橘 | `#FF5A3D` | 主强调（关键操作/军师区/差距） |
| Lime 柠檬黄 | `#D8ED57` | **仅**英雄大数字/高亮点缀 |
| Match 绿 | `#2FA36B` | 匹配点/正向 |
| Coral 浅 | `#FBEDE9` | 差距/珊瑚色 chip 底 |

- 由上述构造显式 `ColorScheme`（light）+ 暗色反转（墨底 + 奶油字，珊瑚不变）。深色模式作为 stretch 打磨项，浅色优先。

### 3.2 字体（黑体·强对比 = 编辑感签名）
- 资源：打包 **思源黑体 / Source Han Sans SC** 仅 **Black(900) + Medium(500)** 两个字重（控制 APK 体积）；`pubspec` 注册 `family: SourceHanSans`。
- `TextTheme`：display/headline = Black 900（紧字距、行高 1.0–1.1），title = 800，body = Medium 500，label/caption = 700。big-number 统计用 display 900。

### 3.3 形状 / 阴影 / 磁贴
- 圆角：磁贴 16–18，pill 按钮全圆角(30)，chip 20。
- 磁贴：填充（白/墨/珊瑚/浅面板）或 **2px 墨描边**两种风格；便当格用 `display:grid` 思路的不等宽块（Flutter 用 `Wrap`/`GridView`/自定义 `Row+Expanded` 组合）。
- 阴影：轻（`0 6 18 rgba(26,24,20,.08)`），避免重投影。

### 3.4 动效（Bento 最出片，落到 §4 交互）
- 磁贴**错峰缩放弹入**（列表 stagger）；大数字 **0→N 滚动**（`TweenAnimationBuilder`）；卡片按压回弹；雷达**描边生长**；流式打字；页面**共享轴转场** + 卡片→详情 `Hero`。

### 3.5 组件清单（restyle 既有 + 新增）
- 重做：`ProfessorCard`（磁贴化，名 800、字段 chip、契合 chip）、`MatchLevelChip`、`FieldChips`、`LoadingView`/`ErrorView`/`EmptyView`（品牌化）、`scaffold_with_bottom_nav`（Bento 选中态）。
- 新增：`BentoTile`、`StatTile`（大数字）、`RadarChart`（§5.1）、`SectionHeader`。

---

## 4. 移动端交互设计（手指优先）

**独立一等章节**。目标直击「创新性·交互」：让录屏一眼看出这是"真 App"而非"Flutter demo"。

### 4.1 全局触控系统（Phase 0，横切）
- **拇指人机工学**：主操作底部锚定（sticky 操作条 / 底部抽屉，不用顶部对话框）；触摸目标 **≥48dp**；单手可达。
- **触觉反馈**：新增 `core/haptics/haptics.dart` 封装 `HapticFeedback`——`selectionClick`(chip/tab/选中)、`lightImpact`(按钮/收藏)、`mediumImpact`(分析/生成完成)、错误模式。
- **下拉刷新**：`RefreshIndicator` 覆盖结果/收藏/历史（重推/刷新）。
- **底部抽屉**：`showModalBottomSheet(isScrollControlled, showDragHandle:true)` / `DraggableScrollableSheet`——拖拽手柄 + 下滑关闭；用于资料录入(`showProfileSheet` 已有，改造)、雷达维度解读、卡片快捷操作、分享。
- **侧滑操作**：`Dismissible` 侧滑删除 + **撤销 SnackBar**（收藏/历史）。
- **长按**：卡片长按→快捷操作抽屉（收藏/对比/分享）；长按进入多选（沿用现有对比入口）。
- **侧滑返回 + Android 预测式返回**；**共享元素** `Hero`（卡片→详情）配合共享轴转场。
- **捏合缩放/平移**：`InteractiveViewer` 包裹雷达（及主页/图片预览）。
- **键盘与聚焦**：`FocusNode` 管理、`resizeToAvoidBottomInset`、滚动/点空白收键盘、键盘提交动作、对话 `ScrollController` 自动到底。
- **乐观更新**：收藏即时生效（已基于 stream），失败回滚。
- **滚动物理**：平台感知（iOS 回弹 / Android 辉光）。
- **无障碍**：尊重 `MediaQuery.textScaler`（不写死高度致大字裁切）、图标按钮 `Semantics` 标签、对比度达标。

### 4.2 逐页手势
| 页面 | 手势 / 交互 |
|---|---|
| 首页/搜索 | 键盘自管理、tag chip 追加(haptic)、提交即搜、滚动收键盘、≥48dp |
| 推荐结果 | 下拉刷新重推 · 折叠头图(需求理解) · 卡片 Hero→详情 · 长按快捷操作 · 骨架屏 |
| 导师详情 | `SliverAppBar` 折叠 · 底部 sticky 操作条(匹配/套磁) · 点按展开分区 |
| **匹配页(旗舰)** | 雷达捏合缩放+点按维度→拖拽抽屉看解读 · 出现时描边+数字滚动 · 完成 `mediumImpact` · sticky 生成套磁 · 下拉=重新生成 |
| 套磁邮件 | 聚焦管理 · 复制(haptic)+系统分享 · 键盘避让 |
| 对比 | 横滑切换导师(`PageView`+圆点) · 候选 `ReorderableListView` 拖拽排序 |
| 收藏/历史 | 侧滑删除+撤销 · 下拉刷新 · 长按多选 |
| 对话/预演 | 滚到底 FAB · 长按气泡复制 · 流式 · 下滑收键盘 |
| 引导 | 可滑动 `PageView`+圆点+跳过 |

---

## 5. 旗舰功能轨（按序 ①→②→③→④）

所有 AI 实现遵循既有模式：`LlmClient.complete(jsonMode:true)` 结构化输出 / `stream` 流式；接地提示词不编造；`Result`/sealed 错误；`core/di/providers.dart` 按 `appConfigProvider.dataSource` 切 mock|ai|http；mock 兜底；中文 UI；缺字段「暂无信息」。

### 5.1 ① 匹配雷达可视化 — *必交，先做*
**领域**（扩展 `domain/entities/match_analysis.dart`）：
```dart
class MatchDimension {
  const MatchDimension({required this.label, required this.score, required this.comment});
  final String label;   // 固定 5 轴之一
  final int score;      // 0–100，信息性契合度（非录取概率）
  final String comment; // 该维度的 AI 逐条解读（接地）
}
// MatchAnalysis 增 field：final List<MatchDimension> dimensions;
```
- **固定 5 轴**（保证雷达可比、五边形整洁）：`方向契合` · `方法匹配` · `地域` · `学历目标` · `产出活跃`。
- **伦理护栏**：分数是**逐维度契合（信息性）**，**非录取概率**；保留 M5「不预测录取概率」免责卡。`FeatureFlags.showMatchScore` 语义启用为"显示契合度可视化（fit, not probability）"。

**数据**：
- `AiMatchAnalysisRepository`：扩展系统提示词，要求在既有 `{summary,strengths,gaps,suggestions}` 上增 `dimensions:[{label,score,comment}]`，`label` 限定 5 轴、`score` 0–100、`comment` 接地；仍 `jsonMode`。解析时 **clamp 0–100**，缺轴则补 `score:0, comment:"信息不足"`，保证雷达永远 5 轴。
- `MockMatchAnalysisRepository`：补 plausible dimensions（离线/演示）。

**表现**：
- 新增 `shared/widgets/radar_chart.dart`（`CustomPainter`）：网格五边形 + 轴 + 数据多边形，**描边生长 + 填充淡入**动画；珊瑚填充/描边、墨网格。
- 重做 `features/match/pages/match_page.dart` `_AnalysisView`：英雄磁贴(综合契合大数字滚动) → `InteractiveViewer(RadarChart)` → 点轴弹底部抽屉(该维 `comment`) → 申请军师区(§5.2) → 匹配点/待补强统计磁贴 → 免责。沿用 `matchProvider` 状态机。

**测试**：`ai_match_analysis_repository_test`（解析 dimensions、clamp、缺轴兜底、坏 JSON→Failure）；`match_provider_test`（idle→analyzing→ready，dimensions 透传）；`radar_chart_test`（渲染 5 轴）；`match_page_test`（轴点击开抽屉）。

### 5.2 ② AI 申请军师 — *Target*
**领域**（新增）：
```dart
// domain/entities/outreach_plan.dart
class PlanStep { const PlanStep({required this.when, required this.action}); final String when; final String action; }
class OutreachPlan {
  const OutreachPlan({required this.steps, required this.talkingPoints});
  final List<PlanStep> steps;          // 行动清单（本周/套磁前/邮件中…）
  final List<String> talkingPoints;    // 谈点
}
// domain/repositories/application_strategy_repository.dart
abstract interface class ApplicationStrategyRepository {
  Future<Result<OutreachPlan>> plan({required Professor professor, required UserProfile profile});
}
```
**数据**：`AiApplicationStrategyRepository(llm)` jsonMode 接地生成；**不编造具体论文标题**（仅用 `researchFields`/`bio`，否则给通用但可执行步骤）。`MockApplicationStrategyRepository`。`core/di` 新增 `applicationStrategyRepositoryProvider`（按 dataSource 切）。复用 `UserProfile`/`profileRepositoryProvider`。

**表现**：匹配页雷达下方"申请军师·行动方案"区（见旗舰页稿）；"一键生成套磁邮件"→ **复用现有** `/email?pid=` 流程。①+② 同屏成"匹配→行动"杀手锏页。

**测试**：`ai_application_strategy_repository_test`（解析/坏 JSON）；`mock_*`；widget（行动清单渲染 + 跳邮件）。

### 5.3 ③ 可解释「为什么是TA」 — *Stretch*
**领域**：
```dart
// domain/entities/evidence_link.dart
class EvidenceLink { const EvidenceLink({required this.youSaid, required this.becauseProfessor}); final String youSaid; final String becauseProfessor; }
// Recommendation 增 field：final List<EvidenceLink> evidence;  // 加性、可空 → 空则不渲染
```
**数据**：`AiRecommendationRepository` 提示词增每位导师 `evidence:[{youSaid,becauseProfessor}]`，接地于候选事实 + 解析后的需求；mock 补样例。**加性变更**：evidence 为空时退化为现状，保证既有推荐链路安全。

**表现**：`ProfessorCard` 可展开"为什么是TA"面板（你说 X → TA 的 Y）。

**测试**：解析 evidence；卡片展开/空态隐藏。

### 5.4 ④ 套磁预演 / 模拟回信 — *Stretch*
**数据**：复用 **chat + `LlmClient.stream`**——以"扮演该导师、基于公开研究信息回复学生草稿"的系统提示词起一段会话（可多轮）。实现为 `chatRepository` 的提示词变体或轻量 `AiOutreachRehearsalRepository`（复用 llm.stream）。
**伦理护栏**：界面显著标注「AI 模拟 · 基于公开研究信息的练习，非本人真实观点」。
**表现**：邮件页/匹配页"预演回信"入口 → chat 式页面（沿用流式与气泡）。
**测试**：provider（mock 流式）；widget（预演气泡 + 免责）。

---

## 6. 完成度收尾（并入 M6）

直接采用 M6 spec 设计，**视觉按本 spec §3 的 Bento**：
- **运行时配置**：`appConfigProvider` 由 `Provider` 改 `NotifierProvider`（`AppConfigController`）+ `initialAppConfigProvider`（注入初值），便于设置页切 mock/ai（见 M6 §2.1）。
- **讲解模式（AI 透明化）**：`LlmClient` 记录最近一次 `LlmTrace{model,messages,rawResponse,elapsedMs}`，仅 `featureFlags.showAiTrace` 开启时记录与展示（结果页/匹配页底部可折叠：需求理解、接地候选数、模型名、可展开原始 prompt/返回）。默认关闭、脱敏（M6 §2.2）。**这是录屏证明"大模型真在工作"的关键。**
- **设置页** `features/settings/`（路由 `/settings`）：数据源开关(无 key 时 ai 置灰)、当前模型、讲解模式开关、清除本地历史/收藏/资料、关于/版本。
- **引导/Splash**：首启 `seenOnboarding` → 可滑动引导(卖点) → 首页；Splash 品牌图。
- **三态打磨**：骨架屏 + 品牌化空/错态（统一 `LoadingView/ErrorView/EmptyView`）。
- **APK**：`minSdk=31`（沿用 M6 确认）；产出两包——①真 AI 包(带 key 联网)、②离线演示包(mock 断网兜底)。
- **作品说明** `docs/作品说明.md`：选题/痛点/价值、架构图、**大模型应用能力清单**（结构化输出/接地生成/多轮/流式/多任务生成/provider 无关+mock）、**功能→评分维度对照表**、演示脚本 + 截图。

---

## 7. 架构与接线

- **分层不变**：`presentation(features/*) → domain(entities + repo 接口) ← data(mock/ai/local)`，横切 `core`。
- **新增/扩展实体**：`MatchDimension`(+`MatchAnalysis.dimensions`)、`OutreachPlan`/`PlanStep`、`EvidenceLink`(+`Recommendation.evidence`)。
- **新增仓储接口**：`ApplicationStrategyRepository`。
- **新增/扩展 data**：`Ai/MockMatchAnalysisRepository`(dimensions)、`Ai/MockApplicationStrategyRepository`、`AiRecommendationRepository`(evidence)、④ 复用 chat/stream。
- **新增 provider**（`core/di/providers.dart`，按 `dataSource` switch，http→`UnimplementedError`）：`applicationStrategyRepositoryProvider`。
- **`appConfigProvider`→`NotifierProvider`**：随之各 feature `*_provider_test` 的 ai 用例 override 由 `appConfigProvider.overrideWithValue` 改为 `initialAppConfigProvider.overrideWithValue`（M6 既有注记）。
- **core 新增**：`haptics/`、motion 工具（转场/stagger）、`shared/widgets/radar_chart.dart`、`bento_tile.dart` 等；路由增 `/splash` `/onboarding` `/settings`。
- **大模型应用模式展示（作品说明清单依据）**：结构化输出(jsonMode→实体)、多轮流式(chat/④)、事实接地 + 可解释(接地提示词 + ③ evidence)、讲解模式可视化。function-calling/RAG 列为未来，不在本轮实现。
- **mock 兜底**全程保留 → 断网演示可跑；AI 模式 `--dart-define` key 注入。

---

## 8. 测试策略（TDD）

| 测试 | 覆盖 |
|---|---|
| `ai_match_analysis_repository_test` | dimensions 解析、clamp 0–100、缺轴兜底、坏 JSON→Failure |
| `radar_chart_test`（widget） | 渲染 5 轴、数据多边形 |
| `match_page_test`（widget） | 轴点击开解读抽屉、状态机 |
| `ai_application_strategy_repository_test` | plan 解析/坏 JSON；mock 形状 |
| `application_strategy_provider_test` | 切 ai/mock、状态流转 |
| `ai_recommendation_repository_test`（扩展） | evidence 解析、空 evidence 退化 |
| `app_config_controller_test` | 切 ai 仅有 key 时允许、切换生效 |
| `ai_trace_test` | 开启 trace 记录、关闭不记录 |
| `settings_page_test` / `onboarding_test`（widget） | 数据源/讲解模式控件、首启跳引导 |
| 交互 widget 测 | `Dismissible` 侧滑、`RefreshIndicator` 下拉、底部抽屉开合 |

> 纯视觉打磨/动效/文档无单测，以 `flutter analyze` + 既有回归全绿 + 人工冒烟为准。

---

## 9. 分期实施计划

| Phase | 内容 | 层级 | 依赖 |
|---|---|---|---|
| **0 · 视觉&交互地基** | `AppTheme` Bento(ColorScheme/TextTheme/组件主题)、思源黑体资源、`Haptics`、motion 工具、`RefreshIndicator`/抽屉/`Hero` 模式、restyle 共享组件 | 必交 · wk1 | — |
| **1 · 旗舰① 匹配雷达** | `MatchDimension`、`RadarChart`、匹配页重做、ai/mock 扩展 + 解析测试 | 必交 · wk1–2 | 0 |
| **2 · 完成度(M6)** | `AppConfigController`、讲解模式(`LlmTrace`)、设置页、引导/Splash、三态打磨、APK、作品说明初稿 | 必交 · wk2 | 0 |
| **3 · 旗舰② 申请军师** | `OutreachPlan`/`ApplicationStrategyRepository`、ai/mock、匹配页行动区→套磁 | Target · wk2–3 | 1 |
| **4 · 旗舰③ 可解释** | `EvidenceLink`、推荐 repo 扩展、卡片展开面板 | Stretch · wk3 | 0 |
| **5 · 旗舰④ 套磁预演** | chat 角色扮演、预演页 | Stretch · wk3–4 | 0 |
| **6 · 打磨 + 演示脚本** | 统一打磨、录屏脚本、终版 APK + 作品说明定稿 + 评分对照 | 必交收尾 · wk4 | 全部 |

每个 Phase 落地为一个独立 plan（writing-plans 阶段拆）。

---

## 10. 演示 / 录屏脚本（≈90s）

Splash → 引导(swipe) → Bento 首页 → 自然语言搜索 → 需求理解 + 可解释推荐③ → 点导师(Hero 转场) → **匹配雷达①描边 + 综合契合 0→83 滚动** → 点某维度→AI 解读抽屉 → 滚到申请军师②行动方案 → 一键生成套磁(流式) → 复制/系统分享 → 收藏侧滑/下拉刷新 → **设置·讲解模式**展示「AI 真在工作：结构化输出 · 接地 N 条导师事实 · 模型名」→ 收束品牌。*录屏叠加手指/手势提示，让"交互"可见。*

---

## 11. 风险与缓解

| 风险 | 缓解 |
|---|---|
| LLM 幻觉(假导师/假论文) | 接地提示词 + mock 事实为准 + 免责 + ③ 证据链；录制用精选真 API 提示 |
| 范围(4 功能/3–4 周) | 必交核心(0/1/2/6)受保护；③④ 加性可丢弃不伤演示 |
| 录制时 API 抖动 | mock 兜底 + 稳定网络录制 + 保留好的一条 take |
| Bento 易花 | 克制配色（柠檬黄仅大数字）+ 统一组件主题 |
| 字体体积 | 思源黑体仅打包 Black+Medium 两字重 |
| 雷达异常分数 | clamp 0–100 + 缺轴兜底 |
| `appConfigProvider` 重构破测 | 经 `initialAppConfigProvider` 迁移既有 override（M6 注记） |

---

## 12. 后续 Backlog（本轮不做）

- **语音输入 / 语音对话**（复杂：权限/STT/流式音频/错误态）——全部完成后再回看。
- `DataSource.http` 真实后端（V1.0）。
- function-calling / 完整 RAG / 埋点 `StubAnalyticsService`。
- 深色模式精修（浅色优先，深色为打磨 stretch）。

---

## 13. 开放问题 / 偏差

1. **取代 M6 §2.4 视觉**：靛蓝/青绿学术色 → Bento 暖编辑识别系统；M6 其余（演示模式/设置/引导/APK/作品说明）保留并入。
2. **`FeatureFlags.showMatchScore` 语义启用**：从隐藏 → 显示"逐维度契合度可视化（信息性，非概率）"，配套免责卡。
3. **② 落点**：申请军师置于**匹配页**（非独立页），与雷达同屏成"匹配→行动"；如内容过长可折叠。
4. **④ 实现选择**：优先复用 `chatRepository` 提示词变体；若耦合过重再独立 `AiOutreachRehearsalRepository`。实现时定。
