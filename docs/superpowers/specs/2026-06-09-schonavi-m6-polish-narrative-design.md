# SchoNavi M6 · 打磨 + AI 能力可视化 + APK + 作品说明设计

- 版本：v1（2026-06-09，首稿——M6 实现前可再细化）
- 关系：收口里程碑，引用前述 M1–M5 与主设计 §7/§8/§9。
- 前置：M1 必须完成；M2–M5 视进度纳入（哪些做了就展示哪些）。

> **范围提示**：M6 含"产品打磨 + 演示基建 + 交付文档"三块，较杂。实现时建议拆成 2-3 个聚焦 plan（① 运行时配置 + AI 可视化；② UI 打磨 + 引导/Splash；③ APK + 作品说明）。本 spec 给设计与清单。

---

## 1. 目标

把项目从"功能可用"抬到"**评委一眼看懂 AI 在哪、好用、完整可交付**"。直接服务四项评分：界面/交互（创新性）、作品完成度，并把**大模型应用能力显式可视化**。

---

## 2. 组件设计

### 2.1 运行时配置切换（演示关键）

现状 `appConfigProvider` 在 `main()` 一次性 override，无法运行时切换。改为可变状态，便于评委现场在 `mock`/`ai` 间切换：

```dart
// core/config/app_config_controller.dart
class AppConfigController extends Notifier<AppConfig> {
  @override
  AppConfig build() => /* 初值来自 main 注入的环境配置 */;
  void setDataSource(DataSource ds) { state = /* copyWith */; } // 仅当 llm.isConfigured 才允许切 ai
}
final appConfigProvider = NotifierProvider<AppConfigController, AppConfig>(...);
```

仓储 provider 已 `ref.watch(appConfigProvider)`，切换后自动重建（无需改各仓储）。

### 2.2 AI 能力可视化（"AI 透明化"）

让"模型做了什么"看得见——答辩最有力的证据：

- 推荐结果页加「查看 AI 详情」：展示**本次需求理解**（已有 `QueryUnderstandingCard`）、**接地候选数**、**模型名**；演示模式下可展开**实际 prompt 与原始返回**（只读、可滚动）。
- 实现：`LlmClient` 增可选**最近一次调用快照**（`LlmTrace{model, messages, rawResponse, elapsedMs}`），仅在 `featureFlags.showAiTrace`（演示模式）开启时记录与展示；默认关闭、不影响生产路径与日志脱敏。
- `features/debug/ai_trace_panel.dart` 或并入结果页底部可折叠区。

### 2.3 设置页（主设计 §8 路由 `/settings`，当前缺失）

新增 `features/settings/`：数据源开关（mock/ai，无 key 时 ai 置灰并提示）、显示当前模型、演示模式开关（`showAiTrace`）、清除本地历史/收藏/背景（隐私，主设计 §6.5）、关于/版本。

### 2.4 UI 打磨与补全

- 补 V0.2 遗留：引导页/Splash（§2.1）——首启 `seenOnboarding`，介绍"AI 选导师"卖点。
- 三态打磨：加载骨架/占位、空态引导文案（放宽条件按钮）、错误态统一。
- 主题与文案：首页文案改为体现"真实大模型"，统一靛蓝/青绿学术色、圆角与层级；应用名/图标/启动图。
- 各 AI 入口（继续追问/套磁邮件/匹配分析/对比）一致的视觉与图标。

### 2.5 APK 构建（主设计 §2 / V0.2 §2.10）

- `minSdk=31` 确认；`flutter build apk --release --dart-define=LLM_API_KEY=sk-xxx`（或不带 key 出 mock 演示包）。
- 文档化两种构建：①「真 AI 包」（带 key，现场联网演示）；②「离线演示包」（mock，断网兜底）。

### 2.6 作品说明 / 答辩叙事（交付文档，非代码）

`docs/作品说明.md`：

- 选题与痛点（升学/保研/申博/留学选导师）、用户与价值（应用价值-可行性/前景）。
- 架构图（三层 + AI 数据源 + 接地）。
- **大模型应用能力清单**：结构化输出（需求理解 JSON）、接地生成/RAG-lite（推荐理由、候选检索接缝）、多轮对话、SSE 流式、多任务生成（套磁邮件/对比/匹配分析）、provider 无关 + mock 兜底。
- 功能 → 评分维度对照表。
- 演示脚本（3-5 分钟动线）+ 截图。

---

## 3. 测试策略（TDD，针对有逻辑的部分）

| 测试 | 覆盖 |
|---|---|
| `app_config_controller_test` | 切 `ai` 仅在有 key 时允许；切换后 `dataSource` 生效 |
| `ai_trace_test` | 开启 trace 时记录 model/messages/raw；关闭时不记录 |
| `settings_page_test`（widget） | 数据源切换控件、清除本地、无 key 时 ai 置灰 |
| `onboarding_test` / `splash_redirect_test` | 首启跳引导、写 `seenOnboarding` 后跳首页 |

> 纯视觉打磨与文档无单测，以 `flutter analyze` + 人工冒烟 + 既有回归全绿为准。

---

## 4. 偏差/开放问题

1. **`appConfigProvider` 由 `Provider` 改 `NotifierProvider`**：为运行时切换；已有 `ref.watch` 调用兼容，`main()` 注入初值方式调整。
2. **AI trace 仅演示模式开启**：避免泄露 prompt/敏感信息，默认关闭，符合主设计 §6.5 脱敏。
3. **拆分实现**：本里程碑建议拆 2-3 个 plan（见顶部范围提示）。
4. **埋点（主设计 §7）**：`StubAnalyticsService` 可选纳入，优先级低于上述。
