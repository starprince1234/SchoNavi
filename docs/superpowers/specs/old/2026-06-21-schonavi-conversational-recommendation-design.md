# SchoNavi 设计 · 对话式推荐 + 横向滑动卡片（ChatGPT/Claude APP + 约会APP 刷卡）

- 版本：v1.3（2026-06-21；稳定性修订）

## 稳定性修订（实现基线）

本节覆盖下文早期方案中与当前实现冲突的部分：

- 每个 `ChatPage` 使用独立的 `autoDispose family` 状态实例，不再共享全局对话状态。
- 推荐轮只调用一次推荐接口；成功后直接展示结构化开场白、推荐卡片和服务端快捷追问，不再追加第二次聊天 LLM 调用。
- 推荐上下文通过 `seedRecommendationTurn` 按“用户原文 → 推荐摘要”顺序写入。
- 请求使用递增操作令牌；页面销毁、切换会话、停止或重启后，旧 Future/Stream 不能更新当前状态。
- 活动状态细分为 `idle/recommending/classifying/streaming`，非空闲期间禁用输入、快捷问题和重复提交。
- LLM 数据源继续使用 LLM 追问分类器；HTTP 数据源使用严格、保守的本地重新筛选判定。
- LLM 模式未配置 Key 时，首页阻止进入聊天；直接访问聊天路由只显示配置错误且不请求仓储。
- 推荐失败提供“重试推荐”；普通聊天中断保留已生成文本；只允许重新生成最新一条普通聊天回复。
- 推荐轮卡片持久化页码并采用响应式紧凑布局，覆盖小屏、长文本和大字体场景。

- 版本：v1.2（2026-06-21；v1.1→v1.2：追问产卡判定由「关键词触发」改为**真 LLM 路由器** `LlmRecommendationNeedClassifier`——既更鲁棒（不漏判「我想要研究CV的」类自然表述），又直击参赛「大模型应用能力」短板，替换掉 `String.contains()` 假智能）
- 关系：建立在 **M1–M5 + Bento Phase 0/1/2 + 个人档案个性化（均已实现）** 之上。补上 M2 spec 当时明确推迟的功能——「对话内嵌推荐卡片」（`2026-06-09-schonavi-m2-streaming-design.md` 当时的非目标项）。
- 直击参赛评分：**创新性·产品交互**维度。当前「输入→跳转列表→跳转追问」是割裂三段式；改成「输入→对话流→卡片在气泡下横向滑动→就地追问可再产卡」连续体验。
- 前置：DeepSeek key 冒烟 `flutter run --dart-define=LLM_API_KEY=...`；导师事实数据始终来自本地 `MockDb`。
- 开发约定：沿用既有分层 + Riverpod 3.2.1 手写 provider + Result/sealed + TDD（见 `schonavi-dev-conventions`）。

---

## 0. Context（为什么做这件事）

用户反馈：当前首页输入后**直接跳转静态推荐列表页**，体验割裂。APP 仿 ChatGPT APP 设计，应体现**对话式**——AI 输出可供**横向滑动**的推荐卡片（借鉴约会 APP「刷卡片」），并借鉴 Claude APP 对话质感。

**现状链路**（割裂三段式）：

```text
首页(home_page.dart) → push /recommendation?q= → RecommendationPage(垂直ListView+ProfessorCard)
  → FAB「继续追问」→ 独立 ChatPage（靠 sessionId 串）
```

**地基已齐**（不是推倒重来）：

- `ChatMessage.relatedRecommendations` 字段早已存在（`lib/domain/entities/chat_message.dart`），气泡留了渲染位（`lib/features/chat/widgets/chat_message_bubble.dart`）但当前**纵向堆叠、从未被填充**。
- `ChatPage` 已有完整对话脚手架（气泡、流式「正在思考…/生成中…」、快捷问题、输入栏、点赞点踩、重新生成、停止生成）。
- `AiRecommendationRepository` 已能产结构化 `RecommendationResult`。
- `AiChatRepository.streamReply` 只 emit 文本，`relatedRecommendations: const []`——对话内推荐从未接通。
- **额外发现**：`MockChatRepository.sendMessage` 其实已会返回 `relatedRecommendations`（相似/换方向/只看某地场景），但 `ChatNotifier._respondTo` 只订 `streamReply` 文字增量、从不读 `ChatResult.relatedRecommendations`——连 mock 路径的卡片都被丢了。

**目标链路**（连续对话式）：

```text
首页「想做CV，想去北京」→ push /chat?q=...
  → 提问=首条用户消息 → AI 流式回复文字 + 气泡下横滑卡片(PageView一次一张)
  → 就地追问「只看北京的」→ AI 在新气泡下再给一横排卡片
```

---

## 1. 已确认的关键决策（与用户 brainstorm + 架构审阅）

| # | 决策点 | 选择 |
| --- | --- | --- |
| 1 | 对话页形态 | **复用 ChatPage**：提交后跳 `/chat?q=...`，提问=首条用户消息，推荐=助手回复。首页保留品牌入口。 |
| 2 | 卡片手势 | **横向 PageView 一次一张** + page indicator + 触觉。 |
| 3 | 卡片密度 | **对话内浓缩 + 点开看全**；点进 `/professor/:id`。 |
| 4 | 推进方式 | 先出设计文档（本文）→ review → 分阶段实现。 |
| 5 | 接线方案 | **方案 A**：`streamReply` 纯文字不动；ChatNotifier 首轮调 `recommendationRepository` 拿卡挂气泡；function-calling（方案 B）留 V1.0。 |
| 6 | Notifier 改法 | **方案 A'**：不改 `start` 签名，新增独立 `bootstrapRecommendations(initialPrompt)` 方法 → 现有 chat 测试零破坏（它们都不 override recommendationRepository）。 |
| 7 | 追问产卡判定 | **真 LLM 路由器** `LlmRecommendationNeedClassifier`（三分类式 need true/false），把追问 + 上一轮推荐摘要喂 LLM 判定；失败降级 false。直击「大模型应用能力」短板，替换 `String.contains()` 假智能。 |

---

## 2. 范围

**In**

- 首页提交路径：`/recommendation?q=` → `/chat?q=`（导师 tab）；`/recommendation` 路由保留兼容。
- 推荐接入对话：助手消息携带 `relatedRecommendations`（首条提问即推荐 + 追问可再推荐）。
- 新组件 `SwipeRecommendationCard` + `RecommendationCarousel`（PageView 一次一张 + indicator + 触觉）。
- 浓缩卡片（头像位/匹配度/理由摘要/收藏/主页）。
- **sessionId 衔接 + 上下文注入**（§4.5，头号架构点）：首轮推荐结果摘要注入 `AiChatRepository._history`，避免 LLM 上下文断层。
- 快捷追问问题用 `RecommendationResult.followUpQuestions`（已有字段，当前未用）动态填充。

**Out / 非目标**

- Tinder 式左滑跳过/右滑收藏语义动作（已确认不采用）。
- 卡片 3D 翻转堆叠动画（标准 PageView 即可）。
- 竞赛推荐对话化（本轮聚焦导师线，后续同模式复用）。
- function-calling（方案 B，留 V1.0）。
- 语音输入、深色模式精修、对话历史跨会话持久化。

---

## 3. 交互流程

### 3.1 首次提问

1. 首页输入 → `context.push('/chat?q=${encoded}')`。
2. ChatPage `initState`：`start(sessionId: 临时id)` 后调 `notifier.bootstrapRecommendations(initialPrompt)`。
3. `bootstrapRecommendations`：
   - 追加 1 条**用户消息**（=提问）。
   - 调 `recommendationRepositoryProvider.getRecommendations(prompt, profile)`（非流式）拿 `RecommendationResult`。
   - 用 `result.sessionId` 作为本会话 `state.sessionId`（§4.5）。
   - **注入上下文**：调 `chatRepositoryProvider.seedContext(sessionId, result)` 把推荐摘要写进 `AiChatRepository._history`（§4.5）。
   - 助手消息 content = **静态模板开场白**（「我理解你关注{interests}，偏好{locations}。为你挑了 N 位合适的导师：」秒开）+ `streamReply` 追加的**流式过渡段**（LLM 补一句建议，保留打字机观感）。
   - 流结束 → `recommendations` 挂到该助手消息 `relatedRecommendations` → 横滑卡出现。
   - 推荐获取失败/空 → 降级纯文字流式（不进 error）。

### 3.2 横滑卡片

- 助手气泡正下方：横向 `PageView`，`viewportFraction ≈ 0.86`（露下一张边缘作「可滑」暗示），固定高度（~240 逻辑像素，避免 ListView 嵌套无限高异常）。
- 单卡 `SwipeRecommendationCard`：4px 珊瑚左条 + 头像位 + 姓名/职称 + 学校院系 + `MatchLevelChip` + 研究方向 chip(1 行省略) + 理由摘要(2-3 行) + 底部「访问主页」「收藏」。
- 卡下 page indicator（`● ● ○`），切页 `Haptics.selection()`；卡片 ≤1 张隐藏 indicator。
- 点卡片 → `/professor/:id`。
- 流式中卡片占位用 `ProfessorCardSkeleton`（复用），流完替真卡。

### 3.3 就地追问

- 输入栏常驻底部（沿用 `_InputBar`）。
- 快捷问题栏改用 `result.followUpQuestions` 动态填充；空时回退硬编码列表。
- 追问 → `recommendationNeedClassifierProvider.needRecommendations(text, lastResult)` 判定（真 LLM 路由）：命中→新一轮 `getRecommendations` + `seedContext` 追加 + 挂卡；未命中→纯文字流式（现状）。
- 多轮持续给卡 = 「AI 输出可横滑推荐」的对话式体验。

### 3.4 欢迎卡处理

`_WelcomeCard`（`lib/features/chat/pages/chat_page.dart`）在 `initialPrompt != null` 时**隐藏**（首轮即产助手消息+卡，欢迎卡多余）；从 `/chat?sid=` 进入的纯追问场景仍显示。

---

## 4. 架构与接线

### 4.1 首轮文字策略（审阅修正）

首轮助手 content = **静态模板开场白（秒开）+ `streamReply` 追加流式过渡段**，而非纯静态模板。模板预填进 buffer 初值，LLM 增量追加其后。system prompt 约束「前文已给开场白，只补过渡建议，勿重复需求复述」。这样既保留打字机观感，又不依赖流式解析出卡片。

### 4.2 ChatNotifier 改动（方案 A'，零测试破坏）

- **不改 `start({sessionId, professorId})` 签名**。
- 新增 `Future<void> bootstrapRecommendations(String initialPrompt)`：守卫 `state.messages.isEmpty` 才执行（防 Notifier 重建误判首轮）；内部调推荐仓储 + seedContext + 组装助手消息。
- `_respondTo(content)` 增「追问轮」分叉：先 `shouldProduceRecommendations(content)` 判定，命中则先 `getRecommendations`+`seedContext` 再流式挂卡，否则纯文字（现状）。
- `regenerate`/`regenerateMessage`：只重跑 `streamReply` 文字段，**不重新调 getRecommendations**（卡片沿用原结果，避免每次重新生成多一次推荐调用）。
- 推荐获取 try/catch：失败降级纯文字，不让整条助手消息进 error。

### 4.3 不走 recommendationProvider（审阅修正）

ChatNotifier 直接 `ref.read(recommendationRepositoryProvider).getRecommendations(prompt:, profile: ref.read(profileProvider))`，**不走 `recommendationProvider`**。理由：

- `recommendationProvider` 内 `unawaited(historyRepositoryProvider.addFromResult(...))` 会把每条对话开场记成独立搜索历史，对话式下语义错位（追问不计、开场片段化）。
- 其 `ref.watch(profileProvider)` 会让 Notifier 在档案变更时重建丢消息；直接读 profile 更可控。
- **是否写搜索历史**：默认仍写（手动调 `addFromResult`，保持历史页「我找过什么导师」可用），spec 标注可调。

### 4.4 否定页面层拼接

不改 ChatNotifier、在 ChatPage 层 watch recommendationProvider 塞伪消息——否定。因追问产卡必须介入 `_respondTo` 流结束回调把卡挂到正确助手消息 id，页面层做不到。Notifier 层装配是唯一可行路径（方案 A' 已是最省改动变体）。

### 4.5 sessionId 衔接与上下文注入（头号架构点，v1.1 新增）

**问题**：`AiChatRepository` 用 `Map<String,List<LlmMessage>> _history` 按 sessionId 维护上下文；`AiRecommendationRepository` 完全无状态，其 sessionId 仅派生 token。对话式下首轮在 ChatNotifier 拿推荐后 `streamReply(sessionId)`，但该 sessionId 在 `_history` 里是**空的**——LLM 看不到刚选了哪些导师，上下文断层（问"第一位的研究方向"会答不出或编造）。

**解法**：

1. 首轮用 `RecommendationResult.sessionId` 作为 `state.sessionId`（路由 `/chat?q=` 不再需要 sid；旧 `/chat?sid=` 路径兼容）。
2. 新增 `ChatRepository.seedContext({sessionId, RecommendationResult})`（接口加**默认空实现**方法，避免破坏既有假仓储）：`AiChatRepository` 实现里 `_history.putIfAbsent(sessionId, () => [LlmMessage('assistant', 推荐摘要)])`，把"已推荐 N 位导师：姓名/方向/匹配理由"作为预置 assistant 消息写入。后续 `streamReply` 即可读到。
3. 追问产卡时复用同一 sessionId 调 `getRecommendations`，新结果**追加更新** seedContext（而非覆盖），保持多轮累积。
4. `professorId` 单导师锚定（从 `/professor/:id` 进 ChatPage）与 seedContext 多导师列表不冲突；professorId 非空时优先单导师锚定。

**实现约束**：`ChatRepository` 当前是 `abstract interface class`，不支持默认方法体。改为 `abstract class` 以提供 `seedContext` 的默认空实现，使 `_StreamChatRepo`/`_FakeChatRepo` 等既有假仓储无需改动即编译通过。

---

## 5. 关键文件清单

**新增**

- `lib/shared/widgets/swipe_recommendation_card.dart` —— 单张浓缩卡（BentoTile + MatchLevelChip + FieldChips + Haptics）。
- `lib/features/chat/widgets/recommendation_carousel.dart` —— 对话内横滑轨道（PageView + indicator + favoriteStatus 监听 + 固定高度）。
- `lib/shared/utils/recommendation_need_classifier.dart` —— 接口 `RecommendationNeedClassifier`（`Future<bool> needRecommendations(followUp, {lastResult})`）。
- `lib/data/ai/llm_recommendation_need_classifier.dart` —— LLM 路由器实现（jsonMode，喂追问+上轮摘要，失败降级 false）+ 单测。

**改动**

- `lib/features/chat/widgets/chat_message_bubble.dart` —— 纵向 ProfessorCard → `RecommendationCarousel`（横滑）。传 onTapRecommendation/收藏/主页回调。
- `lib/features/chat/providers/chat_provider.dart` —— 新增 `bootstrapRecommendations(initialPrompt)`；`_respondTo` 增追问产卡分叉；regenerate 不重产卡；失败降级。
- `lib/features/chat/pages/chat_page.dart` —— 读 `q` 参数驱动 `bootstrapRecommendations`；`initialPrompt != null` 时隐藏 `_WelcomeCard`；快捷问题用 `followUpQuestions`；接线收藏/主页回调。
- `lib/domain/repositories/chat_repository.dart` + `lib/data/ai/ai_chat_repository.dart` —— 接口改 `abstract class` 加 `seedContext` 默认空实现；Ai 实现写 `_history`；Mock 实现等价（mock 已能产卡，seedContext 摘要注入助其多轮一致）。
- `lib/features/home/pages/home_page.dart` —— `_submit()` 导师 tab 的 `path` 改 `/chat`。
- `lib/core/router/app_router.dart` —— `/chat` 加 `q` 参数解析，`sid` 改可选；ChatPage 加 `initialPrompt`。

**复用（不改）**

- `AiRecommendationRepository.getRecommendations`、`BentoTile`/`MatchLevelChip`/`FieldChips`/`Haptics`/`AnimatedEntrance`/`ProfessorCardSkeleton`、流式脚手架（`streamReply`/`streaming` 状态/「正在思考…」）。

---

## 6. 数据模型

基本不动实体。`ChatMessage.relatedRecommendations: List<Recommendation>` 已存在直接用。首轮「我理解你…」融进助手消息文字，不单独加 `queryUnderstanding` 字段（YAGNI）。

---

## 7. 视觉/交互细节（Claude APP + 约会APP）

- 助手气泡：`secondaryContainer` + 12 圆角（现状）。
- 卡片：`BentoTile` 18 圆角 + 4px 珊瑚左条（沿用 ProfessorCard 视觉语言）。
- PageView：`viewportFraction: 0.86` + `BouncingScrollPhysics` + 切页 `Haptics.selection()`；**固定高度**（ListView 嵌套防无限高异常）。
- indicator：圆点，当前页珊瑚实心，其余 outline 半透明；≤1 张隐藏。
- 卡片阶梯入场：随气泡 `AnimatedEntrance`。
- 空推荐：助手文字说明「暂未找到完全符合条件的导师，可尝试…」，不显轨道。

---

## 8. 测试（TDD）

- `recommendation_need_classifier_test.dart`：LLM 输出 need=true→true、need=false→false；LLM 失败/畸形→降级 false；无 lastResult 兜底；prompt 含上轮推荐摘要（张三/计算机视觉）。
- `chat_provider_test.dart` 新增：`bootstrapRecommendations(initialPrompt)` 后助手消息含 `relatedRecommendations`（假 recommendationRepository 返回固定结果）；守卫 messages 非空时不重跑；追问经 needClassifier 命中→再产卡；未命中→纯文字；regenerate 不重产卡；推荐失败降级纯文字。**现有 chat 测试不 override recommendationRepository/needClassifier → 不进推荐分支 → 零破坏**。
- `ai_chat_repository_test.dart` 新增：`seedContext` 后 `_history[sessionId]` 含推荐摘要；后续 `streamReply` 上下文可见。
- `swipe_recommendation_card_test.dart` / `recommendation_carousel_test.dart`：N 张渲染、indicator 数量、点击回调、空列表不显轨道、固定高度。
- `chat_page` widget 测：`q` 参数驱动首轮；`initialPrompt != null` 隐藏欢迎卡；快捷问题来自 `followUpQuestions`。
- `chat_route_test.dart`：新增 `/chat?q=...` 解析；旧 `/chat?sid=` 不破坏。
- 复用 `_FakeLlm`/`_RecordingLlm` 喂固定 JSON，离线确定。

---

## 9. 验证（end-to-end）

1. `flutter test` 全绿（新增 + 更新既有；现有 chat 测试零破坏）。
2. `flutter run --dart-define=LLM_API_KEY=...` 冒烟：
   - 首页输入「想做计算机视觉，想去北京」→ 对话页，助手「正在思考…」→ 模板开场白秒出 → 流式过渡段逐字 → 下方横滑卡，左右滑切页有触觉、indicator 跟随。
   - 点卡进导师详情；收藏生效；主页打开。
   - 快捷问题（来自 followUpQuestions）点击 → 新轮对话；追问「只看上海的」→ AI 回答 + 新横滑卡（验证 seedContext：AI 知道上轮推荐了谁）。
   - 追问「第一位导师的研究方向是什么」→ AI 能基于 seedContext 准确回答（**验证上下文衔接**）。
   - 重新生成/点赞点踩/停止生成 仍正常。
3. 无 key（`MissingLlmClient`）走 mock 路径仍可演示。

---

## 10. 风险与回退

- **风险**：sessionId 上下文注入（seedContext）若遗漏 → 首轮 LLM 上下文断层。**缓解**：§4.5 明确为头号实现项 + 专项测试 `ai_chat_repository_test` 覆盖。
- **风险**：ChatNotifier 改动影响既有 chat 测试。**缓解**：方案 A' 不改 `start` 签名 + `messages.isEmpty` 守卫，现有测试零破坏。
- **风险**：LLM 路由判定漏判/误判（如把解释性追问误判为需产卡，多一次推荐调用）。**缓解**：失败一律降级 false（宁少产卡不阻断）；路由器温度=0 求稳定；首轮必产卡（核心体验已有），追问产卡为增强项。
- **风险**：`ChatRepository` 从 `abstract interface class` 改 `abstract class` 可能影响 `HttpChatRepository` 等实现。**缓解**：默认空实现使所有实现类无需改动；逐一编译验证。
- **回退**：`/recommendation` 路由保留 → 首页 `path` 一行改回即回退列表式。

---

## 11. 后续（不在本轮）

- 竞赛推荐对话化（同模式复用，复用 `RecommendationNeedClassifier`）。
- 方案 B function-calling（真·工具调用产卡，冲大模型应用能力高分，sessionId 天然统一无需 seedContext）。
- 对话历史跨会话持久化（当前 `ChatNotifier` 内存态）。
- 卡片左滑跳过/右滑收藏语义（若后续想要更强约会APP味）。
