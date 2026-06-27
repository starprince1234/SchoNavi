# Fork 式追问会话设计

**日期**：2026-06-27
**状态**：待审阅
**分支**：iter3rc2

## 1. 背景与问题

### 1.1 当前对话流

SchoNavi 导师推荐的主对话在**首页原地**进行（`/home`，导师 tab）。用户输入「想做CV，想去北京」→ `ChatNotifier.bootstrapRecommendations` 产卡 + 开场白，推荐卡片在助手气泡下横向滑动。主 sessionId 形如 `s_chat_xxx`，由 `AiChatRepository._history[sessionId]` 维护完整对话历史（含 `seedRecommendationTurn` 注入的推荐摘要 + 已发生的追问）。

用户在横滑卡片里点开某位导师 → `context.push('/professor/$id')` 进**详情页**。

### 1.2 问题

1. **详情页「继续追问」丢失上下文**：详情页「继续追问」FAB 跳 `/chat?sid=s_prof_${id}&pid=${id}`，派生一个**全新的空 session**（`s_prof_xxx`），与主对话的 `s_chat_xxx` 毫无关系。`AiChatRepository._history` 里这个新 session 是空的——既丢了主对话的推荐上下文，也丢了已发生的追问。
2. **无视觉锚点**：`professorId` 虽传给了 `streamReply`（注入【上下文导师】到 system prompt，LLM 其实知道是哪位导师），但**界面上没有任何视觉锚点**告诉用户「你现在追问的是哪位教授」。
3. **推荐页入口同病**：推荐结果页 `/recommendation` 的「继续追问」FAB 跳 `/chat?sid=${result.sessionId}`，复用主 sessionId 但无 professorId、无视觉锚点。

### 1.3 目标

用户从卡片/详情页「继续追问」时，该追问 session 应是主 session 的一个 **fork（copy-on-fork 分支）**：
- fork 时复制主 session 当前**全部**对话历史到新 forkId，之后独立演进、不回写主 session；
- 追问页**起始即显示**用户所选教授（顶部 sticky 教授条，常驻不随滚动消失）；
- fork 追问内容持久化，可从历史页恢复并继续追问；
- 接口设计面向生产环境，允许新增端点。

## 2. 设计决策汇总

| 决策项 | 结论 |
|---|---|
| Fork 语义 | Copy-on-fork，复制主 session 全部历史，独立演进不回写 |
| forkId | `f_${主sid}_${profId}`，同导师复用唯一 fork；存储预留对话树扩展 |
| fork 入口 | 仅详情页「继续追问」FAB；推荐页「继续追问」FAB 移除（老版遗留） |
| 主 sid 来源 | 路由一路透传 msid（首页→详情页） |
| 追问页 UI | 顶部 sticky 教授条（方案 A），仅该教授追问，无「换一位」 |
| fork 内再推荐 | 不产卡；识别意图→助手说明 + 双选项（P-d：继续问这位 / 回首页重挑） |
| 历史页 | 折叠展开式 v3：主条目仅标题 + 右侧线条加号（无包裹、与标题对齐），点击旋转 45° 展开；子项 = 头像姓氏 + 姓名 + 学校 + 时间；无 fork 也常驻加号，展开空显「暂无追问历史」 |
| 持久化/接口 | 测试期本地持久化，接口面向生产（forkSession/loadHistory/listForks/deleteFork 新接口，可对接 POST/GET/DELETE 端点） |

## 3. 架构

```
主对话(首页原地, s_chat_xxx)
   │ 用户点横滑卡片 → /professor/:id?msid=$mainSid   ← msid 路由透传
   ▼
详情页「继续追问」FAB → context.push('/chat?fork&msid=$mainSid&pid=$profId')
                        ▼
              ChatPage(fork 模式)
                │ startFork() 调 forkSession(msid, pid) → forkId
                │        + loadHistory(forkId) 回填 messages
                ▼
   顶部 sticky 教授条(方案A) + 对话流 + 输入框
   追问独立演进，不回写主 session
   fork 内识别再推荐意图 → 助手说明 + 双选项(P-d)
```

## 4. 数据模型与 domain 接口

### 4.1 新增实体 `ForkRef`

`lib/domain/entities/fork_ref.dart`：

```dart
class ForkRef {
  final String forkId;         // 恢复对话用，跳 /chat?fork&fid=$forkId
  final String mainSessionId;   // 归属主 session（树形挂载用）
  final String professorId;
  final String professorName;   // 头像姓氏 + 姓名展示
  final String university;
  final String? college;        // "清华大学 · 计算机系"
  final DateTime createdAt;
}
```

只存**元数据**（展示 + 恢复入口），对话内容仍由 `loadHistory(forkId)` 按需拉取，不塞进 ForkRef。

**对话树扩展预留**：当前 `ForkRef` 为扁平「主→fork」两层。未来支持「用户编辑已发送消息」时，需在 `ForkRef` 增加 `parentMessageId` 字段，复用同一套树形存储。本次不实现编辑，但 forkId 命名与存储结构不阻碍未来扩展。

### 4.2 `ChatRepository` 接口扩展

`lib/domain/repositories/chat_repository.dart` 在现有 `sendMessage`/`streamReply`/`seedRecommendationTurn` 之上**新增纯抽象方法**（fork 是本次核心能力，所有实现类都应显式实现，避免静默失败）：

```dart
abstract class ChatRepository {
  // 现有三个方法保持不变 ...

  /// 从源会话 fork 出一个新会话：复制源的全部历史到新 forkId，
  /// 绑定 professorId。同主session+同professorId 复用已有 fork（不新建）。
  /// 返回 forkId 供后续追问/恢复。
  /// 生产对接：POST /chat/fork {source_session_id, professor_id}
  Future<Result<String>> forkSession({
    required String sourceSessionId,
    required String professorId,
  });

  /// 拉取某个会话（主或 fork）的全部消息历史，供页面恢复。
  /// 生产对接：GET /chat/{id}/history
  Future<Result<List<ChatMessage>>> loadHistory({
    required String sessionId,
  });

  /// 列出某主 session 下的所有 fork（按 createdAt 倒序），供历史页展开。
  /// 生产对接：GET /chat/sessions/{id}/forks
  Future<Result<List<ForkRef>>> listForks({
    required String mainSessionId,
  });

  /// 删除某个 fork（子项左滑删除）。主 session 不受影响。
  /// 生产对接：DELETE /chat/forks/{forkId}
  Future<Result<void>> deleteFork({required String forkId});
}
```

### 4.3 `ChatState` 扩展

`lib/features/chat/providers/chat_provider.dart` 的 `ChatState` 加 `ForkRef? forkAnchor` 字段：
- `null` = 主对话 / 普通追问，不渲染 sticky 条；
- 非 null = fork 追问，sticky 条据此渲染教授信息。

`professorId` 字段保留。fork 模式下 `forkAnchor.professorId == professorId`，但语义不同：`professorId` 供 `streamReply` 接地用，`forkAnchor` 是 UI 锚点 + fork 身份用。

## 5. 仓储实现（data 层）

### 5.1 持久化后端 `ChatHistoryStore`

`AiChatRepository._history` 当前是内存 `Map<String, List<LlmMessage>>`，fork 要求持久化，故抽出接口：

`lib/data/local/chat_history_store.dart`：
```dart
abstract class ChatHistoryStore {
  Future<List<ChatMessage>?> load(String sessionId);
  Future<void> save(String sessionId, List<ChatMessage> messages);
  Future<List<ForkRef>> listForks(String mainSessionId);
  Future<ForkRef?> findFork(String mainSessionId, String professorId);  // 去重用
  Future<void> saveFork(ForkRef ref);
  Future<void> deleteFork(String forkId);
}
```

mock 下用 `LocalChatHistoryStore`（SharedPreferences + JSON）；未来 HTTP 用 `HttpChatHistoryStore`。`AiChatRepository` 持有 `ChatHistoryStore`，`streamReply`/`seedRecommendationTurn` 改为读写 store 而非内存 Map。

### 5.2 `AiChatRepository` 实现新方法

`lib/data/ai/ai_chat_repository.dart`：

- **`forkSession`**：
  1. `forkId = 'f_${sourceSessionId}_${professorId}'`；
  2. 先 `findFork(sourceSessionId, professorId)`——命中已有 fork 直接返回其 forkId（同导师复用，不允许多次新建）；
  3. 未命中：从 store 读源 session 历史 → 写到 forkId 下 → 构造 `ForkRef`（导师信息从 `db.getProfessor(professorId)` 取）→ `saveFork` → 返回 forkId。
- **`loadHistory`**：从 store 读 `sessionId` 消息列表，转回 `ChatMessage`（含 `relatedRecommendations`）。
- **`listForks` / `deleteFork`**：委托 store。

**LlmMessage 与 ChatMessage 的转换**：`LlmMessage`（role/content）是 LLM 调用内部格式；store 存 `ChatMessageDto`（含推荐卡）。`streamReply` 时从 store 读回，转成 `LlmMessage` 喂 LLM（转换在仓储内）。`seedRecommendationTurn` 的推荐摘要仍以 `LlmMessage` 形式喂 LLM，同时以 `ChatMessage` 形式持久化。

### 5.3 消息持久化 DTO

`lib/data/dto/chat_message_dto.dart`：新增 `ChatMessageDto`（含 `role`/`content`/`createdAt`/`status`/`kind`/`feedback` + `List<RecommendationDto> relatedRecommendations`），复用现有 `RecommendationDto`。`fromJson`/`toJson` 供 `LocalChatHistoryStore` 序列化。

### 5.4 其它实现类

- `MockChatRepository`：加 4 方法实现（复用 `ChatHistoryStore` 或独立内存版）。
- `HttpChatRepository`：4 方法对接未来端点，本次先抛 `UnimplementedError`（http 数据源非本次主线），但**接口已在 domain 层定义好**，满足「接口面向生产」。
- 测试 fake：按需实现。

### 5.5 再产卡行为（fork 内）

fork 内不再产推荐卡。`ChatNotifier.send` 在 fork 模式下：
- `needRecommendations` 判定照常运行；
- 若 `needRecommendations == true`（用户在 fork 里要新推荐），**不调 `_requestRecommendations`**，而是走 `_emitForkReroute(token, content)`：输出一条助手消息（说明 + 双选项按钮，见 §7），不产卡。
- 若 `needRecommendations == false`，走现有 `_streamConversation`（用 forkId 作 sessionId）。

## 6. ChatNotifier 与路由接入

### 6.1 `ChatNotifier` 新增方法

`lib/features/chat/providers/chat_provider.dart`：

```dart
Future<void> startFork({
  required String sourceSessionId,
  required String professorId,
}) async {
  // 1. forkSession(sourceSessionId, professorId) → forkId
  // 2. loadHistory(forkId) 回填 state.messages
  // 3. state.sessionId = forkId, professorId = professorId
  // 4. state.forkAnchor = ForkRef(...)
  // 5. _refreshQuickActions
}

Future<void> resume({
  required String sessionId,
  required bool isFork,
}) async {
  // 恢复路径：fork 模式 loadHistory 回填 + 重建 forkAnchor（listForks 或 store 取 ForkRef）
  // 非 fork（主对话恢复）loadHistory 回填
}
```

`send` 在 fork 模式下拦截再产卡（见 §5.5）。其余 `streamReply`/`seedRecommendationTurn`/`retryRecommendation`/`regenerate` 逻辑不变，自动以 forkId 隔离。

### 6.2 路由参数

`lib/core/router/app_router.dart` 的 `/chat` 路由参数扩展：
- `/chat?fork&msid=$mainSid&pid=$profId` —— 新 fork（从详情页「继续追问」）
- `/chat?fork&fid=$forkId` —— 恢复已有 fork（从历史页子项）
- `/chat?sid=$sid` —— 旧纯追问路径保留兼容

`/professor/:id` 路由加可选 `msid` query 透传。

### 6.3 `ChatPage` 分发

`lib/features/chat/pages/chat_page.dart` 的 `initState`：
```dart
if (widget.forkMode && widget.forkId != null) {
  notifier.resume(sessionId: forkId, isFork: true);
} else if (widget.forkMode) {
  notifier.startFork(sourceSessionId: msid, professorId: pid);
} else {
  // 现有 start / bootstrap 路径不变
}
```

### 6.4 入口接线

- **`professor_page.dart`**「继续追问」FAB：改为 `/chat?fork&msid=$mainSid&pid=$profId`。`mainSid` 来自详情页路由 query `?msid=`（由首页卡片点击透传）。
- **`home_page.dart`** 卡片点击：`context.push('/professor/$id?msid=$mainSid')`，把当前主 sessionId 透传给详情页。主 sessionId 从 `chatProvider` 的 state 取。
- **`recommendation_page.dart`**：移除「继续追问」FAB（推荐页为老版遗留，导师 tab 已改首页对话式）。推荐页本身及抽屉/历史页入口保留兼容。

## 7. UI 组件

### 7.1 sticky 教授条 `ProfessorAnchorBar`

`lib/features/chat/widgets/professor_anchor_bar.dart`：
- 放在 `ChatPage` 的 `Stack` 里消息 `ListView` 之上（`Positioned(top:0)` 或 Column 顶部常驻），不随滚动消失。
- 内容：导师头像（姓氏首字，圆形品牌色）+ 姓名 + 院校/方向 + 「追问中」徽标。
- 点击条 → `context.push('/professor/$pid')` 回详情页。
- 仅 `state.forkAnchor != null` 时渲染。
- 导师信息来源：`ForkRef` 直接取（已含 name/university/college），无需再查 db。

### 7.2 fork 再推荐重路由 `_ForkRerouteActions`

fork 内识别到再推荐意图时，助手气泡下方渲染双选项（P-d）：
```
[助手气泡] 这里咱们专注聊李卫国教授。想看新的导师推荐，回首页重挑一组吧～
  [ 继续问李卫国 ]  [ 回首页重挑 › ]
```
- 左按钮「继续问李卫国」：清空当前输入，聚焦输入框（留在 fork）。
- 右按钮「回首页重挑」：`context.go('/home')` 回首页（首页即新会话入口）。
- 实现：`ChatMessageBubble` 增加可选 `onReroute` 回调。`ChatMessageKind` 新增 `forkReroute` 枚举值（与 `conversation`/`recommendation` 并列）；`ChatState.canRegenerate` 需排除 `forkReroute` kind（重路由消息不可重新生成文字）。该消息无 `relatedRecommendations`。

### 7.3 历史页折叠展开 `_HistoryTile` 改造

`lib/features/history/pages/history_page.dart`：

`_HistoryTile` 从 `ConsumerWidget` 改为 `ConsumerStatefulWidget`，加 `bool _expanded = false`。

**主条目行**（v3 定稿）：
```
[想做CV，想去北京]                    [+]
```
- 仅 `item.prompt` 标题；去掉「为你挑了…」摘要句、角标、时间计数行。
- 右侧加号：纯线条 SVG（无圆形/方形包裹），16px，与标题文字垂直居中对齐，灰色 `#6a6385`。
- 点击加号：`_expanded = !_expanded`，`AnimatedRotation(turns: _expanded ? 0.125 : 0)`（45° = 1/8 圈）变 ×。
- 展开时顶部加虚线分隔，`AnimatedSize`/`CrossFade` 过渡子列表。

**子项行**：
```
[李]  李卫国                    14:22
      清华大学 · 计算机系
```
- 头像：姓氏首字（`professorName` 取首字），圆形品牌色（按 professorId hash 取色或固定 indigo）。
- 姓名（粗体）+ 学校（灰，`university · college`）+ 右侧时间。
- 点击子项 → `context.push('/chat?fork&fid=$forkId')` 恢复 fork 对话。
- 左滑删除：`Dismissible` 包子项，`onDismissed` 调 `deleteFork(forkId)`。

**fork 数据获取**：展开时按需 `ref.read(chatRepositoryProvider).listForks(mainSessionId)`（或新建 `forkListProvider(mainSid)` FutureProvider family 缓存）。收起不查。

**空 fork 处理**：无 fork 时加号仍常驻，点击展开后子列表为空，显示「暂无追问历史」占位。

**主条目删除级联**：现有左滑删 `SearchHistoryItem`（`historyRepository.remove`）。删主条目时级联删其下所有 fork —— 采用 UI 层方案：删除前先 `listForks(mainSessionId)` 逐个 `deleteFork(forkId)`，再 `historyRepository.remove(sessionId)`。不改 `HistoryRepository` 接口，最小侵入。

## 8. 错误处理

- `forkSession` 失败（store 读写异常）：`startFork` 捕获，state 置错误态，sticky 条不渲染，显示「会话加载失败，请重试」+ 重试按钮（复用 `ErrorView`）。
- `loadHistory` 失败：恢复路径同上错误态。
- `listForks` 失败：历史页展开时子列表显示「追问加载失败」，不影响主条目。
- `deleteFork` 失败：`Dismissible` 复位 + SnackBar「删除失败，请重试」。
- fork 内再推荐重路由不涉及网络，无失败面。

## 9. 测试策略

遵循项目 TDD 约定（`ProviderContainer` 注入假仓储测 provider；widget 测用 `MaterialApp.router`）。

**新增/修改测试**：
- `test/data/ai/ai_chat_repository_fork_test.dart`：forkSession 复制历史 + 同导师复用 + listForks/deleteFork。
- `test/data/local/local_chat_history_store_test.dart`：持久化读写 + ForkRef 存取。
- `test/data/dto/chat_message_dto_test.dart`：序列化往返（含推荐卡）。
- `test/features/chat/chat_fork_test.dart`：startFork 回填 + fork 内 send 拦截再产卡走重路由 + sticky 条渲染。
- `test/features/chat/chat_resume_test.dart`：resume 恢复 fork 对话。
- `test/features/chat/professor_anchor_bar_test.dart`：sticky 条渲染 + 点击回详情页。
- `test/features/chat/fork_reroute_test.dart`：再推荐意图触发双选项 + 点击右按钮回首页。
- `test/features/history/history_tile_fork_test.dart`：折叠展开 + 加号旋转 + 子项渲染 + 点击恢复 + 空状态「暂无追问历史」。
- 更新 `chat_entry_points_test.dart`：详情页「继续追问」改为 fork 参数；推荐页 FAB 移除断言。
- 更新 `home_page_test.dart`：卡片点击透传 msid。

每个假仓储实现新 4 方法。基线测试（当前 442+）全绿、`flutter analyze` 0 issue。

## 10. 范围与遗留

**本次范围**：
- fork 领域概念（ForkRef + ChatRepository 4 新方法）+ AiChatRepository/Mock 实现 + ChatHistoryStore 持久化
- ChatNotifier startFork/resume + fork 内再产卡拦截重路由
- sticky 教授条 + 历史页折叠展开 v3
- 详情页/首页入口透传 msid；推荐页 FAB 移除

**遗留（不在本次）**：
- `HttpChatRepository` 4 方法对接真端点（接口已定义，实现抛 UnimplementedError）
- 对话树扩展（用户编辑已发送消息分叉）——存储结构已预留
- 推荐页 `/recommendation` 路由本身保留兼容（抽屉/历史入口仍用）
- `followUpQuestions` 动态填充（沿用现状）

## 11. 影响文件清单

**新增**：
- `lib/domain/entities/fork_ref.dart`
- `lib/data/local/chat_history_store.dart` + `local_chat_history_store.dart`
- `lib/data/dto/chat_message_dto.dart`
- `lib/features/chat/widgets/professor_anchor_bar.dart`
- 对应测试文件

**修改**：
- `lib/domain/repositories/chat_repository.dart`（+4 抽象方法）
- `lib/data/ai/ai_chat_repository.dart`（持久化 + 4 方法）
- `lib/data/mock/mock_chat_repository.dart`（+4 方法）
- `lib/data/http/http_chat_repository.dart`（+4 方法抛 UnimplementedError）
- `lib/features/chat/providers/chat_provider.dart`（ChatState+forkAnchor、startFork/resume、send 拦截）
- `lib/features/chat/pages/chat_page.dart`（fork 分发）
- `lib/features/chat/widgets/chat_message_bubble.dart`（+重路由双选项）
- `lib/core/router/app_router.dart`（/chat fork 参数 + /professor msid）
- `lib/features/professor/pages/professor_page.dart`（FAB 改 fork）
- `lib/features/home/pages/home_page.dart`（卡片点击透传 msid）
- `lib/features/recommendation/pages/recommendation_page.dart`（移除 FAB）
- `lib/features/history/pages/history_page.dart`（_HistoryTile 折叠展开 v3 + 主条目删除级联 fork）
