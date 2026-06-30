# 备赛详情页与 AI 助手会话优化设计

- 日期：2026-06-30
- 状态：已确认，待复审
- 关联：[2026-06-29 备赛日历+AI助手设计](2026-06-29-preparation-calendar-ai-assistant-design.md)（已实现 P0→C 全量）
- 分支：iter4rc1
- 本次优化：不新增领域模型，聚焦三处体验与一处契约缺口——详情页入口收敛、助手会话与关闭不丢失、HTTP 模式助手端点补齐。

## 1. 背景与动机

2026-06-29 的智能备赛日历 + AI 助手已落地（P0 聊天气泡拆分、P1 日期选择器、P2 双段时间模型、P3 水平诊断、P4a/b 改动卡只读+原子应用、C 契约收口均已提交）。本设计是其后置优化，针对实测暴露的四点：

1. **详情页顶部日历图标误触**：[preparation_plan_detail_page.dart:235-239](../../../lib/features/preparation/pages/preparation_plan_detail_page.dart#L235-L239) 的 `Icons.event_outlined` 与右上 PopupMenu 并排，视觉噪音大且与「归档/删除」同处 AppBar，容易误点。应收敛进更多菜单。
2. **助手抽屉关闭即丢失在途请求**：[assistant_drawer.dart](../../../lib/features/preparation/widgets/assistant_drawer.dart) 是 `ConsumerStatefulWidget`，`_turns`/`_cardStatuses`/`_expectedRevisions` 全部挂在 widget state 上；`_send` 用 `widget.plan`（抽屉打开时的旧快照，line 103/117），且 `if (!mounted) return`（line 124）在关闭后丢弃返回结果。关抽屉再重开看不到那轮回复。
3. **缺「清理上下文」**：助手历史随 planId 单线性累积（`AssistantHistoryStore` `Map<planId, List<AssistantTurn>>`，每计划 20 轮），但用户无法在不删计划的前提下重开一段干净对话。
4. **HTTP 模式助手端点缺失**：[HttpPreparationPlanAssistant](../../../lib/data/http/http_preparation_plan_assistant.dart) 向 `/api/v1/preparation-plans/{id}/assistant` 发请求，但真实 FastAPI 后端 [web/backend/app/api/routes.py](../../../web/backend/app/api/routes.py) 只注册了 `/recommendations`、`/professors/{id}`、`/chat/messages` 三端点。Dio 假后端（fake_preparation_assistant_backend.dart）能跑，切到真实 HTTP/后端即 404。

## 2. 范围

### 2.1 做

- 详情页 AppBar：移除 `Icons.event_outlined`，「调整目标日期」并入右上 PopupMenu（保留「归档计划」「删除计划」）。重排逻辑（`PreparationPlanDetailRescheduler` 与 `_changeTargetDate`）完全不变，只换入口位置。
- 助手抽屉：会话状态提升到一个非 `autoDispose` 的 Riverpod controller；关闭抽屉/离开详情页不取消在途请求，结果完成后写入该计划的助手历史；重开抽屉显示进行中或已完成结果。
- 发送时从仓库读取**最新**计划快照与 `revision`，不再用 `widget.plan`。
- 「清理上下文」：抽屉顶部入口，二次确认后清空该计划助手历史（`store.clear(planId)`）并重置内存态；不删除计划。
- 请求 DTO 新增 `requestId`，响应 echo 回来；同步假后端 handler、FastAPI 端点、OpenAPI。`AssistantTurn` 持久化 `requestId`。
- FastAPI 新增 `POST /api/v1/preparation-plans/{plan_id}/assistant`，含 envelope 与校验，并补测试。
- 客户端最终校验不变：所有返回卡仍经 Dart `PlanChangeValidator`，计划写入仍走 `LocalPreparationPlanRepository` 的 compare-and-set。

### 2.2 不做（明确排除）

- **多会话**：不引入 `activeSessionId` / `sessions` / per-plan 多会话指针。「清理上下文」=清空该计划全部助手历史并从头开始，不保留旧会话可回看。
- **历史 store 结构/迁移**：`AssistantHistoryStore` 的 `Map<planId, List<AssistantTurn>>` 结构与 key `preparation_assistant_history.v1` 完全不变，无 v1→v2 迁移。
- **`assistantSessionId`**：不在请求/响应 DTO 中加入 session id。
- **`running`/`interrupted` 落盘与启动恢复**：在途请求只活在 controller 内存里，不写 `running` turn。App 被系统杀死 = 该轮从未落盘，重开看不到半截，不做启动扫描、不新增 turn status 枚举。`AssistantTurn` 现有 `error: bool` 不变。
- 引入新状态管理 / 路由 / 持久化 / HTTP 第三方库。
- 任何导师对话 / 推荐路径改动。

## 3. 数据与契约变更（最小集）

### 3.1 请求/响应 DTO

[lib/domain/repositories/preparation_plan_assistant.dart](../../../lib/domain/repositories/preparation_plan_assistant.dart)：

- `PlanAssistantRequest` 增加必填字段 `final String requestId;`（构造函数加 `required this.requestId`，置于参数列表首或尾，保持既有具名风格）。
- `AssistantReply` 增加 `final String requestId;`（echo；缺失时 DTO 层降级为空串，保证旧 fake 兼容）。

[lib/data/dto/plan_assistant_dtos.dart](../../../lib/data/dto/plan_assistant_dtos.dart)：

- `planAssistantRequestToJson` 输出 `'request_id': req.requestId`。
- `AssistantReplyDto.fromJson` 读取 `json['request_id'] as String? ?? ''`，`toEntity()` 带入 `AssistantReply`。validator 调用与卡截断逻辑不变。

`AssistantHistoryEntry`、`AssistantCardResult` 不变。

### 3.2 AssistantTurn 持久化 requestId

[lib/domain/entities/assistant_turn.dart](../../../lib/domain/entities/assistant_turn.dart)：

- 增加 `final String requestId;`（默认 `''`，保证旧持久化数据 `fromJson` 不破）。
- `toJson` 输出 `'request_id': requestId`（仅在非空时输出，或恒输出空串——选择**恒输出** `'request_id': requestId`，简化且不破坏既有读取）。
- `fromJson` 读取 `(json['request_id'] as String?) ?? ''`。

`error`、`cardStatuses`、`changeSet`、`createdAt` 不变。**不新增 status 枚举**。

### 3.3 假后端 handler

[lib/data/mock/fake_preparation_assistant_backend.dart](../../../lib/data/mock/fake_preparation_assistant_backend.dart)：

- `preparationAssistantHandler` 解析请求体的 `request_id`（从 `options.data` JSON 解码），在响应 `data` 顶层 echo `'request_id': <请求值>`。
- 其余固定回复（moveTask+addTask 卡）不变。

### 3.4 OpenAPI

[docs/openapi.yaml](../../../docs/openapi.yaml)：

- assistant 请求 schema 加 `request_id`（`type: string`，必填）。
- assistant 响应 `data` schema 加 `request_id`（`type: string`）。
- 不改动 `assistant_session_id`、不改动其他字段。

[docs/api-contract.md](../../../docs/api-contract.md) 同步文案。

### 3.5 FastAPI 端点

[web/backend/app/services/schemas.py](../../../web/backend/app/services/schemas.py) 新增 Pydantic 模型：

```python
class PlanSnapshotTask(BaseModel):
    id: str
    title: str
    kind: str | None = None
    estimated_hours: int | None = None
    completed_at: str | None = None
    due_date: str | None = None  # YYYY-MM-DD

class PlanSnapshotPhase(BaseModel):
    key: str
    title: str | None = None
    start_date: str | None = None
    end_date: str | None = None
    tasks: list[PlanSnapshotTask] = Field(default_factory=list)

class PlanSnapshot(BaseModel):
    id: str
    revision: int
    competition: dict
    target_date: str
    timeline_type: str | None = None
    event_end_date: str | None = None
    defense_date: str | None = None
    phases: list[PlanSnapshotPhase] = Field(default_factory=list)

class AssistantHistoryItem(BaseModel):
    role: str
    content: str
    card_results: list[dict] = Field(default_factory=list)

class PlanAssistantRequest(BaseModel):
    request_id: str
    calendar_today: str
    base_plan_revision: int
    plan_snapshot: PlanSnapshot
    user_message: str
    history: list[AssistantHistoryItem] = Field(default_factory=list)

class PlanChangeCardOut(BaseModel):
    id: str
    type: str
    summary: str
    rationale: str
    status: str = "pending"

class PlanChangeSetOut(BaseModel):
    id: str
    base_plan_revision: int
    cards: list[PlanChangeCardOut] = Field(default_factory=list)

class PlanAssistantData(BaseModel):
    reply: str
    change_set: PlanChangeSetOut
    request_id: str

class PlanAssistantEnvelope(BaseModel):
    code: int = 0
    message: str = "ok"
    data: PlanAssistantData
```

[web/backend/app/api/routes.py](../../../web/backend/app/api/routes.py) 新增路由：

```python
@router.post("/api/v1/preparation-plans/{plan_id}/assistant")
async def plan_assistant(plan_id: str, request: PlanAssistantRequest) -> PlanAssistantEnvelope:
    if not request.user_message.strip():
        raise HTTPException(status_code=422, detail="user_message 不能为空")
    if plan_id != request.plan_snapshot.id:
        raise HTTPException(status_code=422, detail="plan_id 与 plan_snapshot.id 不一致")
    if request.base_plan_revision != request.plan_snapshot.revision:
        raise HTTPException(status_code=422, detail="base_plan_revision 与 plan_snapshot.revision 不一致")
    # 返回与假后端一致的示例：一张 moveTask + 一张 addTask。
    return PlanAssistantEnvelope(
        data=PlanAssistantData(
            reply="我整理了两项可单独确认的调整。",
            change_set=PlanChangeSetOut(
                id="cs_backend_1",
                base_plan_revision=request.base_plan_revision,
                cards=[
                    PlanChangeCardOut(
                        id="cc_backend_move", type="move_task",
                        summary="把【核心算法实现】移到 5 月 22 日",
                        rationale="避开期末考试周，同时仍早于提交 DDL。",
                    ),
                    PlanChangeCardOut(
                        id="cc_backend_add", type="add_task",
                        summary="答辩准备阶段新增一次模拟答辩",
                        rationale="在正式答辩前预留复盘时间。",
                    ),
                ],
            ),
            request_id=request.request_id,
        )
    )
```

校验层只做格式与一致性，不改计划，不跑业务校验（业务校验仍在 Dart `PlanChangeValidator`）。响应结构与 Dart `AssistantReplyDto.fromJson` 解码形状一致。

### 3.6 客户端最终校验（不变）

所有返回卡仍经 Dart `PlanChangeValidator`；接受时仍走 `PlanChangeApplier.applyCard` + `LocalPreparationPlanRepository` CAS save + `expectedRevision` bump + stale cascade。后端只返回建议。

## 4. 助手 controller（核心）

### 4.1 状态与 provider

新增 `lib/features/preparation/providers/preparation_assistant_controller.dart`：

```dart
@immutable
class PreparationAssistantControllerState {
  const PreparationAssistantControllerState({
    required this.currentPlan,
    required this.turns,
    required this.sending,
    required this.expectedRevisions,
    required this.cardStatuses,
    required this.applying,
    required this.cardErrors,
  });

  /// 发送/接受时从 repo 读取的最新计划快照。null 表示尚未加载或计划不存在。
  final PreparationPlan? currentPlan;

  /// 镜像 AssistantHistoryStore 的该计划轮次（按时间顺序）。
  final List<AssistantTurn> turns;

  /// 是否有在途请求（仅内存，不落盘）。
  final bool sending;

  /// 每轮 accept 流程的期望计划版本号。
  final Map<String, int> expectedRevisions;

  /// 每轮每张卡的实时状态。
  final Map<String, Map<String, ChangeCardStatus>> cardStatuses;

  /// 接受中的卡 id（防重 + spinner）。
  final Set<String> applying;

  /// 接受失败的卡 id → 错误文案。
  final Map<String, String> cardErrors;

  static const empty = PreparationAssistantControllerState(
    currentPlan: null,
    turns: [],
    sending: false,
    expectedRevisions: {},
    cardStatuses: {},
    applying: {},
    cardErrors: {},
  );

  PreparationAssistantControllerState copyWith({...});  // 标准不可变 copyWith
}
```

```dart
class PreparationAssistantController
    extends Notifier<PreparationAssistantControllerState> {
  PreparationAssistantController(this.planId);

  final String planId;

  @override
  PreparationAssistantControllerState build() {
    // 首帧后加载历史与最新计划。
    Future.microtask(() => load());
    return PreparationAssistantControllerState.empty;
  }

  PreparationPlanRepository get _repo =>
      ref.read(preparationPlanRepositoryProvider);
  AssistantHistoryStore get _store =>
      ref.read(assistantHistoryStoreProvider);
  PreparationPlanAssistant get _assistant =>
      ref.read(preparationPlanAssistantProvider);

  Future<void> load() async {
    final plan = _repo.findById(planId);
    final turns = await _store.list(planId);
    final expected = <String, int>{};
    final statuses = <String, Map<String, ChangeCardStatus>>{};
    for (final t in turns) {
      if (t.changeSet != null) {
        expected[t.id] ??= t.changeSet!.basePlanRevision;
        statuses[t.id] ??= Map<String, ChangeCardStatus>.from(t.cardStatuses);
      }
    }
    state = state.copyWith(
      currentPlan: plan,
      turns: turns,
      expectedRevisions: expected,
      cardStatuses: statuses,
    );
  }
}
```

provider（非 autoDispose，注册在 [preparation_providers.dart](../../../lib/features/preparation/providers/preparation_providers.dart)）：

```dart
final preparationAssistantControllerProvider =
    NotifierProvider.family<PreparationAssistantController,
        PreparationAssistantControllerState, String>(
  PreparationAssistantController.new,
);
```

> **Riverpod 3 适配**：本 repo pin Riverpod 3.2.1，无 `FamilyNotifier`/`arg!`。controller 用 `extends Notifier<State>` + 构造注入 `final String planId`，无参 `build()`，`NotifierProvider.family<Controller,State,String>(Controller.new)`（Riverpod 3 把 family arg 传给构造函数）。读取约定：`ref.watch(provider(planId))` 返回 state，`ref.read(provider(planId).notifier)` 返回 notifier 供调方法。下文所有 `arg!` 均指 `planId` 字段。

**关键不变量：非 autoDispose。** 关闭抽屉只销毁 widget，不销毁 controller，在途 `Future` 继续持有在 controller 上。App 整体退出才释放。

### 4.2 send（关闭不取消）

```dart
Future<void> send(String text) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty || state.sending) return;
  final plan = _repo.findById(planId);           // 最新快照，非 widget.plan
  if (plan == null) return;                     // 计划已删
  final history = state.turns
      .slice(state.turns.length > 10 ? state.turns.length - 10 : 0)
      .map((t) => AssistantHistoryEntry(
            role: 'user', content: t.userMessage,
            cardResults: const <AssistantCardResult>[],
          ))
      .toList();
  final requestId = 'req_${DateTime.now().millisecondsSinceEpoch}';
  state = state.copyWith(sending: true);
  final request = PlanAssistantRequest(
    planId: planId,
    calendarToday: CalendarDate.normalize(DateTime.now()),
    basePlanRevision: plan.revision,          // 最新 revision
    planSnapshot: plan,
    userMessage: trimmed,
    history: history,
    requestId: requestId,
  );
  final result = await _assistant.suggestChanges(request);
  // 不判 mounted（Notifier 无 mounted）。关闭后仍执行落盘与 state 更新。
  switch (result) {
    case Success(:final data):
      final turn = AssistantTurn(
        id: 'turn_${DateTime.now().millisecondsSinceEpoch}',
        planId: planId,
        userMessage: trimmed,
        reply: data.reply,
        createdAt: DateTime.now().toUtc(),
        cardStatuses: {for (final c in data.changeSet.cards) c.id: c.status},
        changeSet: data.changeSet,
        // 服务端 echo 优先，缺失时回退客户端 requestId（spec §3.1 契约）。
        requestId: data.requestId.isNotEmpty ? data.requestId : requestId,
      );
      await _store.append(planId, turn);
      final latest = _repo.findById(planId);    // 重读，避免接受流程基线过旧
      state = state.copyWith(
        currentPlan: latest,
        sending: false,
        turns: [...state.turns, turn],
        expectedRevisions: {...state.expectedRevisions, turn.id: data.changeSet.basePlanRevision},
        cardStatuses: {
          ...state.cardStatuses,
          turn.id: {for (final c in data.changeSet.cards) c.id: c.status},
        },
      );
    case Failure():
      final turn = AssistantTurn(
        id: 'turn_${DateTime.now().millisecondsSinceEpoch}_err',
        planId: planId,
        userMessage: trimmed,
        reply: '助手调用失败，请稍后重试。',
        createdAt: DateTime.now().toUtc(),
        cardStatuses: const {},
        error: true,
        requestId: requestId,                  // 失败无 echo，保留客户端 requestId
      );
      // 失败 turn 是否落盘：落盘（便于重开看到失败记录与重试入口），但无卡。
      await _store.append(planId, turn);
      state = state.copyWith(sending: false, turns: [...state.turns, turn]);
  }
}
```

**失败 turn 落盘决策**：落盘。理由：用户重开抽屉能看到「上一条失败了」并决定重试；不落盘则重开后凭空消失，与单线性历史语义冲突。失败 turn 无 changeSet、无卡，仅 `error:true`。

**`sending` 不落盘**：true 仅在内存；App 被杀后 sending 丢失，重开时该轮从未 append（因为 success/failure 分支才 append），因此不会出现「半截 running turn」。

> 在途 vs 失败 turn 的区别：「在途」指 `sending:true`、请求尚未返回的状态——只活在内存，永不落盘。「失败 turn」指请求已返回 `Failure` 后构造的 `error:true` turn——已结束，正常落盘。两者不矛盾：本设计不落盘的是「未完成的进行中状态」，不是「已完成的失败结果」。

**`.slice` 扩展**：`send` 用到的私有 `extension _ListSlice<T> on List<T>`（`List<T> slice(int start)`）随 `send` 逻辑放入 controller 文件，`state.turns.slice(...)` 依赖它。

### 4.3 accept / decline（搬迁自原 drawer）

把原 drawer 的 `_acceptCard` / `_cascadeStale` / `_declineCard` / `_persistStatuses` 逻辑**原样搬入 controller**，行为完全不变：

- 接受：读最新计划 → revision 不匹配则本 change set 剩余 pending 卡标 stale；匹配则 `PlanChangeApplier.applyCard` → CAS save → 成功标 applied + bump expectedRevision；`ConflictException` 卡保持 pending + 错误；已 applied 幂等返回。
- 拒绝：declined 折叠，可撤销回 pending。
- 卡状态写回 `AssistantHistoryStore.updateCardStatuses`。
- `setState(...)` 全部替换为 `state = state.copyWith(...)`。

签名：`Future<void> acceptCard(AssistantTurn turn, PlanChangeCard card)` / `Future<void> declineCard(...)`。`turn` 入参从 `state.turns` 取，调用方传 turn+card。

### 4.4 clearContext（清理上下文）

```dart
Future<void> clearContext() async {
  if (state.sending) return;                   // 发送中禁止清理
  await _store.clear(planId);                      // 复用现有 AssistantHistoryStore.clear
  state = state.copyWith(
    turns: const [],
    expectedRevisions: const {},
    cardStatuses: const {},
    applying: const {},
    cardErrors: const {},
    // currentPlan 保留：清理的是助手历史，不是计划本身。
  );
}
```

二次确认由 UI（抽屉）弹 `AlertDialog`，controller 只执行清空。`sending` 时 UI 入口禁用，方法内也再判一次。

## 5. UI 改动

### 5.1 详情页 AppBar 收敛

[lib/features/preparation/pages/preparation_plan_detail_page.dart:234-253](../../../lib/features/preparation/pages/preparation_plan_detail_page.dart#L234-L253)：

- 删除 `IconButton(icon: Icon(Icons.event_outlined), ...)`。
- PopupMenu `itemBuilder` 增 `PopupMenuItem(value: 'targetDate', child: Text('调整目标日期'))`，置于「归档计划」「删除计划」之前。
- `onSelected` 增 `if (v == 'targetDate') _changeTargetDate(plan);` 分支。
- `_changeTargetDate`、`PreparationPlanDetailRescheduler` 完全不动。

### 5.2 抽屉改薄为 controller 视图

[lib/features/preparation/widgets/assistant_drawer.dart](../../../lib/features/preparation/widgets/assistant_drawer.dart)：

- 改为 `ConsumerStatefulWidget`（保留 `_input`/`_scroll` 在 Stateful 内）。
- watch `preparationAssistantControllerProvider(widget.planId)` 取 state（Riverpod 3：`ref.watch` 返回 state）。
- 移除 `_turns` / `_cardStatuses` / `_expectedRevisions` / `_applying` / `_cardErrors` / `_loading` 本地字段，全部读 state。
- `_send` → `ref.read(controllerProvider(widget.planId).notifier).send(text)`，`_input.clear()` 仍由 UI 做。
- `_acceptCard` / `_declineCard` → `ref.read(controllerProvider(widget.planId).notifier).acceptCard/declineCard(turn, card)`。
- 渲染逻辑（`_buildConversation` 经 mapper + `ChatMessageBubble` + 横滑卡）不变。
- `_loading` 判断改为 `state.sending`（`sending` 已在 state 中）。
- 构造参数：保留 `planId`；`plan` 参数保留作兜底标题——`_Header` 标题从 `state.currentPlan?.competition.name` 取，缺失时回退 `widget.plan.competition.name`，避免 controller 未加载完成时标题空白。

### 5.3 抽屉「清理上下文」入口

`_Header` 行尾（`IconButton(Icons.close)` 之前）加 `IconButton`：

```dart
IconButton(
  icon: const Icon(Icons.cleaning_services_outlined),
  tooltip: '清理上下文',
  onPressed: state.sending ? null : () => _confirmClear(context, ref),
),
```

`_confirmClear` 弹 `AlertDialog`：「清理上下文会清空本计划的助手对话历史，但不删除计划本身。确认清理？」→ 确认调 `ref.read(controllerProvider(widget.planId).notifier).clearContext()`。`sending` 时按钮禁用。

### 5.4 发送中禁用

- 输入框 `enabled: !state.sending`（既有逻辑 `_loading` 改为 `state.sending`）。
- 发送按钮 `_canSubmit` = `input 非空 && !state.sending`。
- 清理上下文按钮 `sending` 时禁用（见 5.3）。
- 不在 accept/decline 流程中禁用发送（accept 有自己的 `_applying` 防重，与发送互不阻塞）。

## 6. 测试策略

### 6.1 详情页

- AppBar 不再出现 `Icons.event_outlined`。
- PopupMenu 展开后含「调整目标日期」「归档计划」「删除计划」三项。
- 选「调整目标日期」触发 `_changeTargetDate`（mock showDatePicker）后计划未完成任务重排（复用既有 rescheduler 测试语义）。
- 既有归档/删除/任务增删改测试继续通过。

### 6.2 controller

- 发送后关闭抽屉（销毁 widget），请求完成，重开抽屉能看到该轮 reply + 卡（state 在 controller 上存活）。
- 发送中 `state.sending == true`；发送中再次 `send` 被忽略；发送中清理上下文按钮禁用且 `clearContext` 被调用时直接 return。
- 清理上下文后 `state.turns` 为空、`AssistantHistoryStore` 该 planId 列表为空；`currentPlan` 仍在；计划本身未删（`repo.findById` 仍返回）。
- 发送用最新 plan：发送前 `repo.save` 改 plan revision，发送请求的 `basePlanRevision` 反映新值（非打开抽屉时的旧值）。
- 失败 turn 落盘且重开可见 `error:true`、无卡。
- accept/decline/stale/CAS 行为与搬迁前一致（既有 P4b.2 测试断言继续通过，断言改为通过 controller 触发）。

### 6.3 DTO / 契约

- `planAssistantRequestToJson` 含 `request_id`；`AssistantReplyDto.fromJson` 从响应 `request_id` 还原并带入 `AssistantReply.requestId`。
- 旧响应缺 `request_id` → DTO 降级为空串（不抛异常）。
- `AssistantTurn.toJson/fromJson` 往返 `requestId`；旧持久化数据无 `request_id` → 默认 `''`。
- 假后端 handler echo 请求的 `request_id`。

### 6.4 FastAPI

- `POST /api/v1/preparation-plans/{plan_id}/assistant` 成功返回 envelope `{code:0, message:"ok", data:{reply, change_set, request_id}}`，`request_id` 与请求一致。
- 空消息 → 422。
- `plan_id != plan_snapshot.id` → 422。
- `base_plan_revision != plan_snapshot.revision` → 422。
- 响应 `data` 形状与 Dart `AssistantReplyDto.fromJson` 解码兼容（手测或契约测试）。

### 6.5 综合验证

- targeted：`flutter test test/features/preparation/ test/features/chat/ test/data/http/ test/data/local/ test/data/dto/ test/domain/`。
- `flutter analyze`。
- FastAPI：`cd web/backend && uv run python -m pytest -q`（或项目现有后端测试命令），不带 `realdata`。
- 上机肉眼：详情页菜单调整目标日期生效；助手发消息→关抽屉→重开见结果；发送中禁再次发送与清理；清理上下文清空历史但计划仍在；HTTP 模式（启动 FastAPI + 指向真后端）助手不再 404。无法上机的项逐项说明。

## 7. 文件清单

**修改：**

- `lib/domain/repositories/preparation_plan_assistant.dart`（DTO + 实体字段 requestId）
- `lib/domain/entities/assistant_turn.dart`（requestId 持久化）
- `lib/data/dto/plan_assistant_dtos.dart`（序列化 + 解码 requestId）
- `lib/data/mock/fake_preparation_assistant_backend.dart`（echo request_id）
- `lib/features/preparation/pages/preparation_plan_detail_page.dart`（AppBar 收敛）
- `lib/features/preparation/widgets/assistant_drawer.dart`（改薄 + 清理入口）
- `lib/features/preparation/providers/preparation_providers.dart`（注册 controller）
- `docs/openapi.yaml`、`docs/api-contract.md`（request_id）
- `web/backend/app/services/schemas.py`（Pydantic 模型）
- `web/backend/app/api/routes.py`（assistant 路由）
- `web/backend/tests/test_api.py`（端点测试）

**新增：**

- `lib/features/preparation/providers/preparation_assistant_controller.dart`（controller + state）
- `test/features/preparation/providers/preparation_assistant_controller_test.dart`
- `test/features/preparation/pages/preparation_plan_detail_page_test.dart`（AppBar 断言，若无则新建或追加既有）
- `test/features/preparation/widgets/assistant_drawer_test.dart`（清理上下文 + 关闭不丢失，若无则新建或追加）

## 8. 实现分期建议

1. **契约层**：DTO/实体/假后端/OpenAPI 加 `requestId`（最小且独立，先绿）。
2. **FastAPI 端点**：schemas + 路由 + 测试。
3. **controller**：state + load + send（关闭不取消）+ clearContext，抽屉先不改，单测覆盖。
4. **抽屉改薄 + 清理入口**：抽屉改读 controller，加清理上下文入口，搬 accept/decline。
5. **详情页 AppBar 收敛**：移图标、并入菜单。
6. **回归 + 上机验证**：targeted test → analyze → 后端 pytest → 三场景肉眼。

每期独立可验证。契约层与 FastAPI 可并行；controller 是抽屉改薄的前置。
