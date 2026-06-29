# 备赛详情页与 AI 助手会话优化 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 收敛详情页日期入口、让助手在途请求跨抽屉关闭存活并按最新计划发送、补齐 HTTP 模式助手后端端点，并向请求/响应加入 `request_id`。

**Architecture:** 不动领域模型与会话单线性结构。把助手抽屉的会话状态（turns/卡片状态/在途标志/接受流程）提升到一个非 `autoDispose` 的 `FamilyNotifier` controller，widget 退化为视图。详情页 AppBar 日历按钮并入 PopupMenu。FastAPI 补 `/api/v1/preparation-plans/{plan_id}/assistant`。请求/响应加 `request_id` 并 echo。

**Tech Stack:** Flutter/Dart, flutter_riverpod 3 (手写 Notifier), dio, shared_preferences, FastAPI/Pydantic。不引入新依赖。

**Spec:** [docs/superpowers/specs/2026-06-30-preparation-assistant-session-polish-design.md](../specs/2026-06-30-preparation-assistant-session-polish-design.md)

## Global Constraints

- `request_id` 是客户端生成的字符串（`req_<ms>`），请求体携带、响应 echo、`AssistantTurn` 持久化。旧响应/旧持久化数据缺 `request_id` 时空串降级，不抛异常。
- 助手会话仍是 `AssistantHistoryStore` 的 `Map<planId, List<AssistantTurn>>` 单线性结构，key `preparation_assistant_history.v1` 不变，无迁移。
- 「清理上下文」= `store.clear(planId)` + 重置内存态，不删计划、不引入多会话。
- 在途 `sending` 只在 controller 内存，永不落盘；失败 turn（已结束、`error:true`）正常落盘。App 被杀后 in-flight 轮不落盘，无启动恢复。
- controller 用 `NotifierProvider.family<..., String>`，**非 autoDispose**（关闭抽屉不销毁 state）。
- 客户端最终校验不变：返回卡仍经 `PlanChangeValidator`，计划写入仍走 `LocalPreparationPlanRepository` CAS + `expectedRevision` bump + stale cascade。
- 后端只返回建议卡，不改计划、不跑业务校验（业务校验仍在 Dart）。
- 保留中文产品文案风格；默认无注释，仅在不明显处加短注释。
- 不引入新状态管理/路由/持久化/HTTP 第三方库。
- 每期独立可验证：先 targeted `flutter test`，再 `flutter analyze`。后端 `cd web/backend && uv run python -m pytest -q`（不带 `realdata`）。
- 提交规范：`feat(preparation): ...` / `feat(chat): ...` / `test(preparation): ...` / `feat(backend): ...` / `docs(api): ...`。不提交 API key。

---

## File Structure（新增 / 修改总览）

**契约层（先做，最小且独立）：**
- `lib/domain/repositories/preparation_plan_assistant.dart`（修改：`PlanAssistantRequest`/`AssistantReply` 加 `requestId`）
- `lib/domain/entities/assistant_turn.dart`（修改：加 `requestId` 持久化）
- `lib/data/dto/plan_assistant_dtos.dart`（修改：序列化 + 解码 `request_id`）
- `lib/data/mock/fake_preparation_assistant_backend.dart`（修改：echo `request_id`）
- `docs/openapi.yaml`（修改：请求/响应 `request_id`）
- `docs/api-contract.md`（修改：`request_id` 文案）

**FastAPI 后端：**
- `web/backend/app/services/schemas.py`（修改：Pydantic 模型）
- `web/backend/app/api/routes.py`（修改：assistant 路由）
- `web/backend/tests/test_api.py`（修改：端点测试）

**controller（核心）：**
- `lib/features/preparation/providers/preparation_assistant_controller.dart`（新：state + Notifier）
- `lib/features/preparation/providers/preparation_providers.dart`（修改：注册 controller）

**UI：**
- `lib/features/preparation/widgets/assistant_drawer.dart`（修改：改薄为 controller 视图 + 清理入口）
- `lib/features/preparation/pages/preparation_plan_detail_page.dart`（修改：AppBar 收敛）

---

# Phase A：契约层（request_id）

> 依赖：无。最小且独立，先全绿。

## Task A.1：PlanAssistantRequest / AssistantReply 加 requestId

**Files:**
- Modify: `lib/domain/repositories/preparation_plan_assistant.dart:32-72`
- Test: `test/domain/repositories/preparation_plan_assistant_test.dart`（新建）

**Interfaces:**
- Produces: `PlanAssistantRequest.requestId`（`final String requestId;`，构造必填）；`AssistantReply.requestId`（`final String requestId;`，echo）

- [ ] **Step 1: 写失败测试**

Create `test/domain/repositories/preparation_plan_assistant_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/domain/repositories/preparation_plan_assistant.dart';

PreparationPlan _plan() => PreparationPlan(
      id: 'pp_1',
      competition: CompetitionSnapshot(
        id: 'comp_demo',
        name: 'Demo',
        category: '计算机类',
        rulesSummary: CompetitionRulesSummary(
          signupTime: '', contestTime: '', teamSize: '', format: '', organizer: '', officialUrl: null,
        ),
      ),
      targetDate: DateTime(2026, 5, 30),
      timelineType: CompetitionTimelineType.submission,
      weeklyCommitment: WeeklyCommitment.hours6to10,
      experienceLevel: ExperienceLevel.intermediate,
      status: PreparationPlanStatus.active,
      phases: const [],
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

void main() {
  test('PlanAssistantRequest 携带 requestId', () {
    final req = PlanAssistantRequest(
      planId: 'pp_1',
      calendarToday: DateTime(2026, 5, 1),
      basePlanRevision: 1,
      planSnapshot: _plan(),
      userMessage: '往后挪',
      requestId: 'req_123',
    );
    expect(req.requestId, 'req_123');
  });

  test('AssistantReply 携带 requestId', () {
    const reply = AssistantReply(
      reply: '已调整',
      changeSet: PlanChangeSet(id: 'cs_1', basePlanRevision: 1, cards: []),
      requestId: 'req_123',
    );
    expect(reply.requestId, 'req_123');
  });
}
```

注意：`AssistantReply` 当前构造是 `const AssistantReply({required this.reply, required this.changeSet})`，本测试传 `requestId` 会编译失败（正是期望的 FAIL）。`PlanChangeSet` 来自 `package:scho_navi/domain/entities/plan_change_card.dart`，已被 `preparation_plan_assistant.dart` 导出（`import '../entities/plan_change_card.dart';`），测试需 `import 'package:scho_navi/domain/entities/plan_change_card.dart';` 引入 `PlanChangeSet`——若未导出则直接 import 该实体文件。

修正 import：在测试文件顶部加：

```dart
import 'package:scho_navi/domain/entities/plan_change_card.dart';
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/domain/repositories/preparation_plan_assistant_test.dart`
Expected: FAIL（`requestId` 未定义 / `PlanAssistantRequest` 缺参数）。

- [ ] **Step 3: 实现 requestId 字段**

修改 `lib/domain/repositories/preparation_plan_assistant.dart`。

`PlanAssistantRequest` 构造（line 32-44）加 `required this.requestId,` 并在断言后加 `final String requestId;` 字段：

```dart
class PlanAssistantRequest {
  PlanAssistantRequest({
    required this.planId,
    required this.calendarToday,
    required this.basePlanRevision,
    required this.planSnapshot,
    required this.userMessage,
    required this.requestId,
    this.history = const <AssistantHistoryEntry>[],
  }) : assert(
          planId == planSnapshot.id,
          'planId ($planId) 必须与 planSnapshot.id (${planSnapshot.id}) 一致',
        );

  final String planId;
  final DateTime calendarToday;
  final int basePlanRevision;
  final PreparationPlan planSnapshot;
  final String userMessage;
  final List<AssistantHistoryEntry> history;

  /// 客户端生成的请求标识，服务端 echo 回来，用于跨抽屉关闭追踪该轮。
  final String requestId;
}
```

`AssistantReply`（line 67-72）改为：

```dart
class AssistantReply {
  const AssistantReply({
    required this.reply,
    required this.changeSet,
    this.requestId = '',
  });

  final String reply;
  final PlanChangeSet changeSet;

  /// 服务端 echo 的请求标识（缺失时为空串，兼容旧 fake）。
  final String requestId;
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/domain/repositories/preparation_plan_assistant_test.dart`
Expected: PASS。

- [ ] **Step 5: 修复受影响调用点**

`requestId` 是必填，所有构造 `PlanAssistantRequest` 的地方都会编译失败。当前仅 `lib/features/preparation/widgets/assistant_drawer.dart:114-121` 构造它（Task C 会重写此处，但本 Task 要让 analyze 通过）。搜索其他构造点：

Run: `grep -rn "PlanAssistantRequest(" lib test`
对每处构造补 `requestId: 'req_test'`（测试）或本 Task 先在 drawer 临时补 `requestId: 'req_${DateTime.now().millisecondsSinceEpoch}'`（Task C 会搬走）。**本 Task 只补编译，不改逻辑。**

修改 `lib/features/preparation/widgets/assistant_drawer.dart:114` 的 `PlanAssistantRequest(...)`，在 `history: history,` 后加：

```dart
      requestId: 'req_${DateTime.now().millisecondsSinceEpoch}',
```

- [ ] **Step 6: 运行 analyze + 受影响测试**

Run: `flutter analyze lib/domain/repositories/preparation_plan_assistant.dart lib/features/preparation/widgets/assistant_drawer.dart`
Expected: No issues。

Run: `flutter test test/domain/repositories/preparation_plan_assistant_test.dart test/data/http/ test/data/ai/ai_preparation_plan_assistant_test.dart`
Expected: PASS（若有 ai/http assistant 测试因缺 requestId 构造失败，按 Step 5 补 `requestId: 'req_test'`）。

- [ ] **Step 7: Commit**

```bash
git add lib/domain/repositories/preparation_plan_assistant.dart lib/features/preparation/widgets/assistant_drawer.dart test/domain/repositories/preparation_plan_assistant_test.dart
git commit -m "feat(preparation): 助手请求/响应加 requestId"
```

---

## Task A.2：AssistantTurn 持久化 requestId

**Files:**
- Modify: `lib/domain/entities/assistant_turn.dart:6-49`
- Test: `test/domain/entities/assistant_turn_test.dart`（新建，若已有则追加）

**Interfaces:**
- Produces: `AssistantTurn.requestId`（`final String requestId;`，默认 `''`，`toJson`/`fromJson` 兼容旧数据）

- [ ] **Step 1: 写失败测试**

Create `test/domain/entities/assistant_turn_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/assistant_turn.dart';
import 'package:scho_navi/domain/entities/plan_change_card.dart';

void main() {
  test('toJson/fromJson 往返 requestId', () {
    final turn = AssistantTurn(
      id: 'turn_1',
      planId: 'pp_1',
      userMessage: '问',
      reply: '答',
      createdAt: DateTime.utc(2026, 6, 30),
      cardStatuses: const {},
      requestId: 'req_abc',
    );
    final decoded = AssistantTurn.fromJson(turn.toJson());
    expect(decoded.requestId, 'req_abc');
  });

  test('旧持久化数据缺 request_id 默认空串', () {
    final json = <String, dynamic>{
      'id': 'turn_old',
      'plan_id': 'pp_1',
      'user_message': '问',
      'reply': '答',
      'created_at': '2026-06-30T00:00:00.000Z',
      'error': false,
      'card_statuses': <String, dynamic>{},
    };
    final decoded = AssistantTurn.fromJson(json);
    expect(decoded.requestId, '');
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/domain/entities/assistant_turn_test.dart`
Expected: FAIL（`requestId` 未定义）。

- [ ] **Step 3: 加 requestId 字段**

修改 `lib/domain/entities/assistant_turn.dart`。构造（line 6-16）加 `this.requestId = '',`：

```dart
class AssistantTurn {
  const AssistantTurn({
    required this.id,
    required this.planId,
    required this.userMessage,
    required this.reply,
    required this.createdAt,
    required this.cardStatuses,
    this.changeSet,
    this.error = false,
    this.requestId = '',
  });

  final String id;
  final String planId;
  final String userMessage;
  final String reply;
  final PlanChangeSet? changeSet;
  final DateTime createdAt;
  final bool error;
  final Map<String, ChangeCardStatus> cardStatuses;

  /// 跨抽屉关闭追踪该轮的请求标识（echo 自服务端，旧数据缺失时为空串）。
  final String requestId;
```

`toJson`（line 27-36）加 `'request_id': requestId,`：

```dart
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'plan_id': planId,
    'user_message': userMessage,
    'reply': reply,
    if (changeSet != null) 'change_set': changeSet!.toJson(),
    'created_at': createdAt.toIso8601String(),
    'error': error,
    'card_statuses': _encodeStatuses(cardStatuses),
    'request_id': requestId,
  };
```

`fromJson`（line 38-49）加 `requestId:` 字段读取：

```dart
  factory AssistantTurn.fromJson(Map<String, dynamic> json) => AssistantTurn(
    id: json['id'] as String,
    planId: json['plan_id'] as String,
    userMessage: json['user_message'] as String,
    reply: json['reply'] as String,
    changeSet: json['change_set'] == null
        ? null
        : PlanChangeSet.fromJson(json['change_set'] as Map<String, dynamic>),
    createdAt: DateTime.parse(json['created_at'] as String),
    error: (json['error'] as bool?) ?? false,
    cardStatuses: _decodeStatuses(json['card_statuses']),
    requestId: (json['request_id'] as String?) ?? '',
  );
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/domain/entities/assistant_turn_test.dart`
Expected: PASS。

- [ ] **Step 5: analyze + 受影响测试**

Run: `flutter analyze lib/domain/entities/assistant_turn.dart`
Expected: No issues。

Run: `flutter test test/data/local/assistant_history_store_test.dart test/features/preparation/widgets/assistant_turn_message_mapper_test.dart`
Expected: PASS（mapper 不读 requestId，不受影响；history store 解码路径走 fromJson，默认值兼容）。

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/assistant_turn.dart test/domain/entities/assistant_turn_test.dart
git commit -m "feat(preparation): AssistantTurn 持久化 requestId"
```

---

## Task A.3：DTO 序列化/解码 request_id

**Files:**
- Modify: `lib/data/dto/plan_assistant_dtos.dart:11-69`
- Test: `test/data/dto/plan_assistant_dtos_test.dart`（新建，若已有则追加）

**Interfaces:**
- Produces: `planAssistantRequestToJson` 输出 `request_id`；`AssistantReplyDto.fromJson` 解析 `request_id`（缺失降级 `''`）并带入 `AssistantReply.requestId`。`PlanChangeSetDto` 不动（request_id 不属于 card set）。

- [ ] **Step 1: 写失败测试**

Create `test/data/dto/plan_assistant_dtos_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/calendar_date.dart';
import 'package:scho_navi/data/dto/plan_assistant_dtos.dart';
import 'package:scho_navi/domain/entities/plan_change_card.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/domain/repositories/preparation_plan_assistant.dart';
import 'package:scho_navi/domain/services/plan_change_validator.dart';

PreparationPlan _plan() => PreparationPlan(
      id: 'pp_1',
      competition: CompetitionSnapshot(
        id: 'comp_demo',
        name: 'Demo',
        category: '计算机类',
        rulesSummary: CompetitionRulesSummary(
          signupTime: '', contestTime: '', teamSize: '', format: '', organizer: '', officialUrl: null,
        ),
      ),
      targetDate: DateTime(2026, 5, 30),
      timelineType: CompetitionTimelineType.submission,
      weeklyCommitment: WeeklyCommitment.hours6to10,
      experienceLevel: ExperienceLevel.intermediate,
      status: PreparationPlanStatus.active,
      phases: const [],
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

void main() {
  test('planAssistantRequestToJson 输出 request_id', () {
    final req = PlanAssistantRequest(
      planId: 'pp_1',
      calendarToday: CalendarDate.normalize(DateTime(2026, 5, 1)),
      basePlanRevision: 1,
      planSnapshot: _plan(),
      userMessage: '问',
      requestId: 'req_xyz',
    );
    final json = planAssistantRequestToJson(req);
    expect(json['request_id'], 'req_xyz');
  });

  test('AssistantReplyDto.fromJson 解析 request_id 并带入 entity', () {
    final data = <String, dynamic>{
      'reply': '已调整',
      'request_id': 'req_xyz',
      'change_set': {
        'id': 'cs_1',
        'base_plan_revision': 1,
        'cards': <dynamic>[],
      },
    };
    final snapshot = PlanSnapshot.fromPlan(_plan(), calendarToday: DateTime(2026, 5, 1));
    final dto = AssistantReplyDto.fromJson(data, snapshot);
    expect(dto.toEntity().requestId, 'req_xyz');
  });

  test('AssistantReplyDto 旧响应缺 request_id 降级空串', () {
    final data = <String, dynamic>{
      'reply': '已调整',
      'change_set': {
        'id': 'cs_1',
        'base_plan_revision': 1,
        'cards': <dynamic>[],
      },
    };
    final snapshot = PlanSnapshot.fromPlan(_plan(), calendarToday: DateTime(2026, 5, 1));
    final dto = AssistantReplyDto.fromJson(data, snapshot);
    expect(dto.toEntity().requestId, '');
  });
}
```

注意：`PlanSnapshot.fromPlan(PreparationPlan plan, {required DateTime calendarToday})` 签名与 [HttpPreparationPlanAssistant](../../../lib/data/http/http_preparation_plan_assistant.dart) 用法一致，上述调用正确。`PlanChangeSet` 来自 `package:scho_navi/domain/entities/plan_change_card.dart`，需在该测试顶部 import。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/dto/plan_assistant_dtos_test.dart`
Expected: FAIL（`request_id` 未序列化 / 未解码）。

- [ ] **Step 3: 实现 DTO**

修改 `lib/data/dto/plan_assistant_dtos.dart`。

`planAssistantRequestToJson`（line 11-32）在 `'user_message': req.userMessage,` 后加：

```dart
    'request_id': req.requestId,
```

完整改后的 map 起始：

```dart
Map<String, dynamic> planAssistantRequestToJson(PlanAssistantRequest req) {
  return <String, dynamic>{
    'calendar_today': CalendarDate.toIsoDay(req.calendarToday),
    'base_plan_revision': req.basePlanRevision,
    'plan_snapshot': req.planSnapshot.toJson(),
    'user_message': req.userMessage,
    'request_id': req.requestId,
    if (req.history.isNotEmpty)
      'history': req.history
          .map((h) => <String, dynamic>{
                'role': h.role,
                'content': h.content,
                if (h.cardResults.isNotEmpty)
                  'card_results': h.cardResults
                      .map((c) => <String, dynamic>{
                            'card_id': c.cardId,
                            'status': c.status,
                          })
                      .toList(),
              })
          .toList(),
  };
}
```

`AssistantReplyDto`（line 43-69）：构造加 `requestId` 字段，`fromJson` 读取，`toEntity` 带入。

```dart
class AssistantReplyDto {
  AssistantReplyDto({
    required this.reply,
    required this.changeSet,
    this.requestId = '',
  });

  final String reply;
  final PlanChangeSet changeSet;
  final String requestId;

  factory AssistantReplyDto.fromJson(
    Map<String, dynamic> json,
    PlanSnapshot planSnapshot,
  ) {
    final raw = PlanChangeSetDto.fromJson(json);
    final validated = PlanChangeValidator.validate(raw.changeSet, planSnapshot);
    return AssistantReplyDto(
      reply: raw.reply,
      changeSet: raw.changeSet.copyWith(cards: validated),
      requestId: (json['request_id']?.toString()) ?? '',
    );
  }

  AssistantReply toEntity() => AssistantReply(
        reply: reply,
        changeSet: changeSet,
        requestId: requestId,
      );
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/data/dto/plan_assistant_dtos_test.dart`
Expected: PASS。

- [ ] **Step 5: analyze + http/ai assistant 测试**

Run: `flutter analyze lib/data/dto/plan_assistant_dtos.dart`
Expected: No issues。

Run: `flutter test test/data/http/ test/data/ai/ai_preparation_plan_assistant_test.dart`
Expected: PASS（http/ai 路径走 `AssistantReplyDto`，requestId 缺失降级空串）。

- [ ] **Step 6: Commit**

```bash
git add lib/data/dto/plan_assistant_dtos.dart test/data/dto/plan_assistant_dtos_test.dart
git commit -m "feat(preparation): 助手 DTO 序列化/解码 request_id"
```

---

## Task A.4：假后端 handler echo request_id

**Files:**
- Modify: `lib/data/mock/fake_preparation_assistant_backend.dart:14-59`
- Test: `test/data/mock/fake_preparation_assistant_backend_test.dart`（新建，若已有则追加）

**Interfaces:**
- Produces: `preparationAssistantHandler` 解析请求体 `request_id` 并在响应 `data` echo

- [ ] **Step 1: 写失败测试**

Create `test/data/mock/fake_preparation_assistant_backend_test.dart`:

```dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/mock/fake_preparation_assistant_backend.dart';

RequestOptions _req(Map<String, dynamic> body) => RequestOptions(
      path: '/api/v1/preparation-plans/pp_1/assistant',
      method: 'POST',
      data: body,
      baseUrl: 'https://fake.local',
    );

void main() {
  test('echo 请求的 request_id', () async {
    final resp = await preparationAssistantHandler(_req({
      'request_id': 'req_echo_1',
      'calendar_today': '2026-05-01',
      'base_plan_revision': 1,
      'plan_snapshot': {'id': 'pp_1', 'revision': 1},
      'user_message': '问',
    }));
    final body = await resp.data.toList();
    final json = jsonDecode(utf8.decode(body[0])) as Map<String, dynamic>;
    expect(json['data']['request_id'], 'req_echo_1');
  });
}
```

注意：`ResponseBody` 的 `data` 是 `Stream<List<int>>`；上面用 `toList()` + `utf8.decode` 读取。`RequestOptions` 构造的必需参数以实际 dio 版本为准，若报缺参，补 `connectTimeout`/`receiveTimeout` 等默认值或用 `RequestOptions(path: ..., method: 'POST')..data = body`。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/mock/fake_preparation_assistant_backend_test.dart`
Expected: FAIL（响应无 `request_id`，`json['data']['request_id']` 为 null → 断言失败）。

- [ ] **Step 3: 实现 echo**

修改 `lib/data/mock/fake_preparation_assistant_backend.dart`。把 `preparationAssistantHandler` 改为解析请求 `request_id`：

```dart
Future<ResponseBody> preparationAssistantHandler(
  RequestOptions options,
) async {
  // 解析请求体的 request_id 并 echo（兼容缺失：默认空串）。
  String requestId = '';
  final data = options.data;
  if (data is Map) {
    requestId = (data['request_id']?.toString()) ?? '';
  } else if (data is String) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        requestId = (decoded['request_id']?.toString()) ?? '';
      }
    } catch (_) {}
  }
  return ResponseBody.fromString(
    jsonEncode({
      'code': 0,
      'message': 'ok',
      'data': {
        'request_id': requestId,
        'reply': '我整理了两项可单独确认的调整。',
        'change_set': {
          'id': 'cs_fake_1',
          'base_plan_revision': 1,
          'cards': [
            {
              'id': 'cc_fake_move',
              'type': 'move_task',
              'target_task_id': 'task_core_algo',
              'new_date': '2026-05-22',
              'summary': '把【核心算法实现】移到 5 月 22 日',
              'rationale': '避开期末考试周，同时仍早于提交 DDL。',
              'status': 'pending',
            },
            {
              'id': 'cc_fake_add',
              'type': 'add_task',
              'target_phase_key': 'defense_prep',
              'new_task': {
                'title': '第二次模拟答辩',
                'estimated_hours': 3,
                'due_date': '2026-06-05',
                'note': '记录评委追问',
              },
              'summary': '答辩准备阶段新增一次模拟答辩',
              'rationale': '在正式答辩前预留复盘时间。',
              'status': 'pending',
            },
          ],
        },
      },
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/data/mock/fake_preparation_assistant_backend_test.dart`
Expected: PASS。

- [ ] **Step 5: 回归 assistant drawer 测试**

Run: `flutter test test/features/preparation/widgets/assistant_drawer_test.dart`
Expected: PASS（drawer 走 fake handler，echo 不影响渲染断言）。

- [ ] **Step 6: Commit**

```bash
git add lib/data/mock/fake_preparation_assistant_backend.dart test/data/mock/fake_preparation_assistant_backend_test.dart
git commit -m "feat(preparation): 假后端 echo request_id"
```

---

## Task A.5：OpenAPI + api-contract.md 加 request_id

**Files:**
- Modify: `docs/openapi.yaml:837-849`（请求 schema）、`918-924`（响应 schema）
- Modify: `docs/api-contract.md:675`（assistant 节）

**Interfaces:**
- 无代码接口，纯文档同步。

- [ ] **Step 1: 改 OpenAPI 请求 schema**

修改 `docs/openapi.yaml` line 837-849 的 `PreparationAssistantRequest`：`required` 加 `request_id`，`properties` 加 `request_id`。

```yaml
    PreparationAssistantRequest:
      type: object
      required: [calendar_today, base_plan_revision, plan_snapshot, user_message, request_id]
      properties:
        calendar_today: { type: string, format: date }
        base_plan_revision: { type: integer, minimum: 0 }
        plan_snapshot:
          $ref: '#/components/schemas/PreparationAssistantPlanSnapshot'
        user_message: { type: string }
        request_id: { type: string, description: 客户端生成，服务端 echo }
        history:
          type: array
          items:
            $ref: '#/components/schemas/PreparationAssistantHistoryTurn'
```

- [ ] **Step 2: 改 OpenAPI 响应 schema**

修改 `docs/openapi.yaml` line 918-924 的 `PreparationAssistantResult`：`required` 加 `request_id`，`properties` 加 `request_id`。

```yaml
    PreparationAssistantResult:
      type: object
      required: [reply, change_set, request_id]
      properties:
        reply: { type: string }
        change_set:
          $ref: '#/components/schemas/PreparationChangeSet'
        request_id: { type: string, description: echo 自请求 }
```

- [ ] **Step 3: 改 api-contract.md**

在 `docs/api-contract.md` 的 assistant 节（line 675 起）请求示例 JSON 加 `"request_id": "req_..."`，并在响应示例加 `"request_id": "req_..."`；在该节说明里加一行：「`request_id` 由客户端生成（`req_<ms>`），服务端在响应 `data` 中原样 echo，用于跨抽屉关闭追踪该轮」。

先 Read 该节确切内容再 Edit（避免与现有示例结构错位）。

- [ ] **Step 4: Commit**

```bash
git add docs/openapi.yaml docs/api-contract.md
git commit -m "docs(api): 助手端点 request_id 契约"
```

---

# Phase B：FastAPI 端点

> 依赖：无（可与 A 并行，但本计划顺序执行）。修复 HTTP 模式助手 404。

## Task B.1：Pydantic 模型

**Files:**
- Modify: `web/backend/app/services/schemas.py`（文件末尾追加）
- Test: 暂无独立单测（B.3 端点测试覆盖）

**Interfaces:**
- Produces: `PlanSnapshotTask`、`PlanSnapshotPhase`、`PlanSnapshot`、`AssistantHistoryItem`、`PlanAssistantRequest`、`PlanChangeCardOut`、`PlanChangeSetOut`、`PlanAssistantData`、`PlanAssistantEnvelope`

- [ ] **Step 1: 追加 Pydantic 模型**

在 `web/backend/app/services/schemas.py` 末尾追加（保持文件已有 `from pydantic import BaseModel, Field` 与 `from __future__ import annotations`）：

```python
class PlanSnapshotTask(BaseModel):
    id: str
    title: str
    kind: str | None = None
    estimated_hours: int | None = None
    completed_at: str | None = None
    due_date: str | None = None


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

- [ ] **Step 2: 运行后端现有测试不破**

Run: `cd web/backend && uv run python -m pytest -q`
Expected: 现有测试 PASS（仅新增模型，未接路由）。

- [ ] **Step 3: Commit**

```bash
git add web/backend/app/services/schemas.py
git commit -m "feat(backend): 助手端点 Pydantic 模型"
```

---

## Task B.2：assistant 路由

**Files:**
- Modify: `web/backend/app/api/routes.py`
- Test: `web/backend/tests/test_api.py`（B.3 加测试）

**Interfaces:**
- Produces: `POST /api/v1/preparation-plans/{plan_id}/assistant` 返回 `PlanAssistantEnvelope`，校验 user_message 非空 / plan_id 一致 / revision 一致，否则 422

- [ ] **Step 1: 加路由**

修改 `web/backend/app/api/routes.py`。在顶部 import 加：

```python
from app.services.schemas import (
    ChatMessageRequest,
    ChatMessageResponse,
    PlanAssistantEnvelope,
    PlanAssistantRequest,
    PlanChangeCardOut,
    PlanChangeSetOut,
    PlanAssistantData,
    ProfessorDetail,
    RecommendationRequest,
    RecommendationResponse,
)
```

在文件末尾（`send_message` 路由之后）追加：

```python
@router.post("/api/v1/preparation-plans/{plan_id}/assistant", response_model=PlanAssistantEnvelope)
async def plan_assistant(plan_id: str, request: PlanAssistantRequest) -> PlanAssistantEnvelope:
    if not request.user_message.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="user_message 不能为空",
        )
    if plan_id != request.plan_snapshot.id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="plan_id 与 plan_snapshot.id 不一致",
        )
    if request.base_plan_revision != request.plan_snapshot.revision:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="base_plan_revision 与 plan_snapshot.revision 不一致",
        )
    return PlanAssistantEnvelope(
        data=PlanAssistantData(
            reply="我整理了两项可单独确认的调整。",
            change_set=PlanChangeSetOut(
                id="cs_backend_1",
                base_plan_revision=request.base_plan_revision,
                cards=[
                    PlanChangeCardOut(
                        id="cc_backend_move",
                        type="move_task",
                        summary="把【核心算法实现】移到 5 月 22 日",
                        rationale="避开期末考试周，同时仍早于提交 DDL。",
                    ),
                    PlanChangeCardOut(
                        id="cc_backend_add",
                        type="add_task",
                        summary="答辩准备阶段新增一次模拟答辩",
                        rationale="在正式答辩前预留复盘时间。",
                    ),
                ],
            ),
            request_id=request.request_id,
        )
    )
```

注意：路由路径以 `/api/v1/...` 开头，而 `main.py` 的 `include_router(router, prefix="/api")` 会再加 `/api` 前缀，导致实际路径变成 `/api/api/v1/...`。**需确认**：现有 `/recommendations` 路由在 routes.py 里写的是 `/recommendations`（无 `/api`），经 prefix 变成 `/api/recommendations`，测试也打 `/api/recommendations`。因此本路由应写为 `/v1/preparation-plans/{plan_id}/assistant`（无 `/api`），实际暴露 `/api/v1/preparation-plans/{plan_id}/assistant`，与 Dart 客户端 `/api/v1/preparation-plans/{id}/assistant` 一致。

**修正路由装饰器路径**为：

```python
@router.post("/v1/preparation-plans/{plan_id}/assistant", response_model=PlanAssistantEnvelope)
```

- [ ] **Step 2: 运行后端测试（B.3 写测试后再跑）**

暂跳过，B.3 写测试后一起验证。

- [ ] **Step 3: Commit（与 B.3 合并提交）**

---

## Task B.3：assistant 端点测试

**Files:**
- Modify: `web/backend/tests/test_api.py`（文件末尾追加）

**Interfaces:**
- 无

- [ ] **Step 1: 写测试**

在 `web/backend/tests/test_api.py` 末尾追加：

```python
def _assistant_body(plan_id: str = "pp_1", revision: int = 1, message: str = "往后挪") -> dict:
    return {
        "request_id": "req_test_1",
        "calendar_today": "2026-05-01",
        "base_plan_revision": revision,
        "plan_snapshot": {
            "id": plan_id,
            "revision": revision,
            "competition": {},
            "target_date": "2026-05-30",
        },
        "user_message": message,
    }


def test_plan_assistant_success_envelope() -> None:
    response = client.post(
        "/api/v1/preparation-plans/pp_1/assistant",
        json=_assistant_body(),
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["code"] == 0
    assert payload["message"] == "ok"
    data = payload["data"]
    assert data["request_id"] == "req_test_1"
    assert data["reply"]
    assert data["change_set"]["base_plan_revision"] == 1
    assert len(data["change_set"]["cards"]) == 2


def test_plan_assistant_rejects_empty_message() -> None:
    response = client.post(
        "/api/v1/preparation-plans/pp_1/assistant",
        json=_assistant_body(message="   "),
    )
    assert response.status_code == 422


def test_plan_assistant_rejects_plan_id_mismatch() -> None:
    response = client.post(
        "/api/v1/preparation-plans/pp_other/assistant",
        json=_assistant_body(plan_id="pp_1"),
    )
    assert response.status_code == 422


def test_plan_assistant_rejects_revision_mismatch() -> None:
    response = client.post(
        "/api/v1/preparation-plans/pp_1/assistant",
        json=_assistant_body(revision=1) | {"base_plan_revision": 5},
    )
    assert response.status_code == 422
```

注意：`_assistant_body(revision=1) | {"base_plan_revision": 5}` 用 dict 合并制造 revision 不一致（plan_snapshot.revision=1，base_plan_revision=5）。Python 3.9+ 支持 `|`。

- [ ] **Step 2: 运行测试确认通过**

Run: `cd web/backend && uv run python -m pytest web/backend/tests/test_api.py -q`（或 `uv run python -m pytest -q`）
Expected: PASS（含 4 个新测试 + 既有）。

若 `plan_id_mismatch` 测试 422 但因 Pydantic 校验先报别的错，确认：FastAPI 先做 path/body 解析，body 解析成功后再进函数体校验。`pp_other` 路径与 `pp_1` body 不一致在函数体里校验，应返回 422。若实际返回 422 但 detail 不同，调整断言只判 status code（已只判 422）。

- [ ] **Step 3: Commit**

```bash
git add web/backend/app/api/routes.py web/backend/tests/test_api.py
git commit -m "feat(backend): 备赛助手端点+校验+测试"
```

---

# Phase C：助手 controller（核心）

> 依赖：A（requestId 字段已存在）。controller 是抽屉改薄的前置。

## Task C.1：controller state + provider

**Files:**
- Create: `lib/features/preparation/providers/preparation_assistant_controller.dart`
- Modify: `lib/features/preparation/providers/preparation_providers.dart`（注册 provider）
- Test: `test/features/preparation/providers/preparation_assistant_controller_test.dart`（新建）

**Interfaces:**
- Consumes: `preparationPlanRepositoryProvider`、`assistantHistoryStoreProvider`、`preparationPlanAssistantProvider`（均已在 preparation_providers.dart）
- Produces: `PreparationAssistantControllerState`（不可变 state）；`preparationAssistantControllerProvider = NotifierProvider.family<PreparationAssistantController, PreparationAssistantControllerState, String>`

- [ ] **Step 1: 写失败测试（load + 空初始态）**

Create `test/features/preparation/providers/preparation_assistant_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/providers/preparation_assistant_controller.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';

PreparationPlan _plan({String id = 'pp_1', int revision = 1}) => PreparationPlan(
      id: id,
      competition: CompetitionSnapshot(
        id: 'comp_demo',
        name: 'Demo',
        category: '计算机类',
        rulesSummary: CompetitionRulesSummary(
          signupTime: '', contestTime: '', teamSize: '', format: '', organizer: '', officialUrl: null,
        ),
      ),
      targetDate: DateTime(2026, 5, 30),
      timelineType: CompetitionTimelineType.submission,
      weeklyCommitment: WeeklyCommitment.hours6to10,
      experienceLevel: ExperienceLevel.intermediate,
      status: PreparationPlanStatus.active,
      phases: const [],
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      revision: revision,
    );

Future<ProviderContainer> _container({bool savePlan = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    initialAppConfigProvider.overrideWithValue(
      const AppConfig(
        dataSource: DataSource.llm,
        api: ApiConfig(baseUrl: 'https://fake.local'),
      ),
    ),
  ]);
  addTearDown(container.dispose);
  if (savePlan) {
    await container.read(preparationPlanRepositoryProvider).save(_plan(revision: 0));
  }
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('初始 state 为 empty，load 后注入 currentPlan', () async {
    final container = await _container(savePlan: true);
    final ctrl = container.read(preparationAssistantControllerProvider('pp_1'));
    // 首帧后 microtask load。
    await Future<void>.delayed(Duration.zero);
    expect(ctrl.state.turns, isEmpty);
    expect(ctrl.state.sending, isFalse);
    expect(ctrl.state.currentPlan, isNotNull);
    expect(ctrl.state.currentPlan!.id, 'pp_1');
  });
}
```

注意：`DataSource.llm` 下 `preparationPlanAssistantProvider` 会解析 `AiPreparationPlanAssistant`，本测试不发送，故 LLM 客户端配置缺失不影响 load。若 `AppConfig` 构造签名不同，按 `lib/core/config/app_config.dart` 实际签名调整。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/preparation/providers/preparation_assistant_controller_test.dart`
Expected: FAIL（controller 未定义）。

- [ ] **Step 3: 实现 controller state + load**

Create `lib/features/preparation/providers/preparation_assistant_controller.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar_date.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/assistant_turn.dart';
import '../../../domain/entities/plan_change_card.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../domain/repositories/preparation_plan_assistant.dart';
import '../../../domain/repositories/preparation_plan_repository.dart';
import '../../../domain/services/plan_change_applier.dart';
import '../../../data/local/assistant_history_store.dart';
import 'preparation_providers.dart';

/// 备赛助手抽屉的会话状态（spec §4.1）。不可变；由
/// [PreparationAssistantController] 维护。`sending` 仅内存，不落盘。
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

  final PreparationPlan? currentPlan;
  final List<AssistantTurn> turns;
  final bool sending;
  final Map<String, int> expectedRevisions;
  final Map<String, Map<String, ChangeCardStatus>> cardStatuses;
  final Set<String> applying;
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

  PreparationAssistantControllerState copyWith({
    PreparationPlan? currentPlan,
    List<AssistantTurn>? turns,
    bool? sending,
    Map<String, int>? expectedRevisions,
    Map<String, Map<String, ChangeCardStatus>>? cardStatuses,
    Set<String>? applying,
    Map<String, String>? cardErrors,
  }) =>
      PreparationAssistantControllerState(
        currentPlan: currentPlan ?? this.currentPlan,
        turns: turns ?? this.turns,
        sending: sending ?? this.sending,
        expectedRevisions: expectedRevisions ?? this.expectedRevisions,
        cardStatuses: cardStatuses ?? this.cardStatuses,
        applying: applying ?? this.applying,
        cardErrors: cardErrors ?? this.cardErrors,
      );
}

/// 备赛助手会话 controller（spec §4）。非 autoDispose——关闭抽屉不销毁 state，
/// 在途请求跨关闭继续执行并落盘。按 planId 家族化。
class PreparationAssistantController
    extends FamilyNotifier<PreparationAssistantControllerState, String> {
  @override
  PreparationAssistantControllerState build(String planId) {
    Future.microtask(() => load());
    return PreparationAssistantControllerState.empty;
  }

  String get _planId => arg!;
  PreparationPlanRepository get _repo =>
      ref.read(preparationPlanRepositoryProvider);
  AssistantHistoryStore get _store =>
      ref.read(assistantHistoryStoreProvider);
  PreparationPlanAssistant get _assistant =>
      ref.read(preparationPlanAssistantProvider);

  Future<void> load() async {
    final plan = _repo.findById(_planId);
    final turns = await _store.list(_planId);
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

在 `lib/features/preparation/providers/preparation_providers.dart` 末尾追加 provider 注册：

```dart
import 'preparation_assistant_controller.dart';
```
（顶部 import 区加）

```dart
/// 备赛助手会话 controller：非 autoDispose，关闭抽屉不销毁在途请求。
final preparationAssistantControllerProvider =
    NotifierProvider.family<PreparationAssistantController,
        PreparationAssistantControllerState, String>(
  PreparationAssistantController.new,
);
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/preparation/providers/preparation_assistant_controller_test.dart`
Expected: PASS。

- [ ] **Step 5: analyze**

Run: `flutter analyze lib/features/preparation/providers/preparation_assistant_controller.dart lib/features/preparation/providers/preparation_providers.dart`
Expected: No issues。

- [ ] **Step 6: Commit**

```bash
git add lib/features/preparation/providers/preparation_assistant_controller.dart lib/features/preparation/providers/preparation_providers.dart test/features/preparation/providers/preparation_assistant_controller_test.dart
git commit -m "feat(preparation): 助手 controller state+load"
```

---

## Task C.2：controller send（关闭不取消 + 读最新计划）

**Files:**
- Modify: `lib/features/preparation/providers/preparation_assistant_controller.dart`（加 `send` + `_slice` 扩展）
- Test: `test/features/preparation/providers/preparation_assistant_controller_test.dart`（追加）

**Interfaces:**
- Produces: `PreparationAssistantController.send(String text)`；`sending` 仅内存；失败 turn 落盘 `error:true`

- [ ] **Step 1: 写失败测试（send 成功落盘 + 关闭不取消）**

追加到 `test/features/preparation/providers/preparation_assistant_controller_test.dart`。需要一个可控的 `PreparationPlanAssistant` fake，通过 override `preparationPlanAssistantProvider`。在文件顶部 import 加：

```dart
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/plan_change_card.dart';
import 'package:scho_navi/domain/repositories/preparation_plan_assistant.dart';
import 'package:dio/dio.dart';
import 'package:scho_navi/data/mock/fake_backend.dart';
```

加一个可控 fake assistant（用 Completer 模拟延迟，验证关闭不取消）：

```dart
class _ControllableAssistant implements PreparationPlanAssistant {
  _ControllableAssistant(this.completer);
  final Completer<AssistantReply> completer;
  int callCount = 0;
  PlanAssistantRequest? lastRequest;

  @override
  Future<Result<AssistantReply>> suggestChanges(PlanAssistantRequest request) async {
    callCount++;
    lastRequest = request;
    try {
      final reply = await completer.future;
      return Success(reply);
    } catch (e) {
      return Failure(ServerException());
    }
  }
}
```

测试：

```dart
test('send 成功追加 turn 并落盘', () async {
  final completer = Completer<AssistantReply>();
  final fake = _ControllableAssistant(completer);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    initialAppConfigProvider.overrideWithValue(
      const AppConfig(dataSource: DataSource.llm, api: ApiConfig(baseUrl: 'https://fake.local')),
    ),
    preparationPlanAssistantProvider.overrideWithValue(fake),
  ]);
  addTearDown(container.dispose);
  await container.read(preparationPlanRepositoryProvider).save(_plan(revision: 0));

  final ctrl = container.read(preparationAssistantControllerProvider('pp_1'));
  await Future<void>.delayed(Duration.zero); // 让 load 完成

  ctrl.send('往后挪');
  expect(ctrl.state.sending, isTrue);
  completer.complete(const AssistantReply(
    reply: '已调整',
    changeSet: PlanChangeSet(id: 'cs_1', basePlanRevision: 1, cards: []),
    requestId: 'req_x',
  ));
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero); // 让 append + state 刷新

  expect(ctrl.state.sending, isFalse);
  expect(ctrl.state.turns, hasLength(1));
  expect(ctrl.state.turns.first.reply, '已调整');
  expect(ctrl.state.turns.first.requestId, 'req_x');
  expect(fake.lastRequest!.basePlanRevision, 1);
  // 落盘
  final persisted = await container.read(assistantHistoryStoreProvider).list('pp_1');
  expect(persisted, hasLength(1));
  expect(persisted.first.reply, '已调整');
});

test('send 用最新计划 revision（发送前改计划）', () async {
  final completer = Completer<AssistantReply>();
  final fake = _ControllableAssistant(completer);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    initialAppConfigProvider.overrideWithValue(
      const AppConfig(dataSource: DataSource.llm, api: ApiConfig(baseUrl: 'https://fake.local')),
    ),
    preparationPlanAssistantProvider.overrideWithValue(fake),
  ]);
  addTearDown(container.dispose);
  final repo = container.read(preparationPlanRepositoryProvider);
  await repo.save(_plan(revision: 0)); // revision -> 1

  final ctrl = container.read(preparationAssistantControllerProvider('pp_1'));
  await Future<void>.delayed(Duration.zero);

  // 发送前手工改计划：revision 1 -> 2。
  await repo.save(_plan(revision: 1).copyWith(personalizedSummary: '手动'));

  ctrl.send('问');
  completer.complete(const AssistantReply(
    reply: '答',
    changeSet: PlanChangeSet(id: 'cs_1', basePlanRevision: 2, cards: []),
  ));
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);

  // 请求的 basePlanRevision 应是最新 2，而非 load 时的 1。
  expect(fake.lastRequest!.basePlanRevision, 2);
});

test('send 失败 turn 落盘 error:true', () async {
  final completer = Completer<AssistantReply>();
  final fake = _ControllableAssistant(completer);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    initialAppConfigProvider.overrideWithValue(
      const AppConfig(dataSource: DataSource.llm, api: ApiConfig(baseUrl: 'https://fake.local')),
    ),
    preparationPlanAssistantProvider.overrideWithValue(fake),
  ]);
  addTearDown(container.dispose);
  await container.read(preparationPlanRepositoryProvider).save(_plan(revision: 0));

  final ctrl = container.read(preparationAssistantControllerProvider('pp_1'));
  await Future<void>.delayed(Duration.zero);

  ctrl.send('问');
  completer.completeError(Exception('boom'));
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);

  expect(ctrl.state.sending, isFalse);
  expect(ctrl.state.turns, hasLength(1));
  expect(ctrl.state.turns.first.error, isTrue);
  final persisted = await container.read(assistantHistoryStoreProvider).list('pp_1');
  expect(persisted.first.error, isTrue);
});

test('sending 中再次 send 被忽略', () async {
  final completer = Completer<AssistantReply>();
  final fake = _ControllableAssistant(completer);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    initialAppConfigProvider.overrideWithValue(
      const AppConfig(dataSource: DataSource.llm, api: ApiConfig(baseUrl: 'https://fake.local')),
    ),
    preparationPlanAssistantProvider.overrideWithValue(fake),
  ]);
  addTearDown(container.dispose);
  await container.read(preparationPlanRepositoryProvider).save(_plan(revision: 0));

  final ctrl = container.read(preparationAssistantControllerProvider('pp_1'));
  await Future<void>.delayed(Duration.zero);

  ctrl.send('第一条');
  expect(fake.callCount, 1);
  ctrl.send('第二条'); // sending 中，应忽略
  expect(fake.callCount, 1);
  completer.complete(const AssistantReply(
    reply: '答', changeSet: PlanChangeSet(id: 'cs_1', basePlanRevision: 1, cards: []),
  ));
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  expect(ctrl.state.turns, hasLength(1));
});
```

import 还需 `dart:async`（Completer）。在文件顶部加 `import 'dart:async';`。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/preparation/providers/preparation_assistant_controller_test.dart`
Expected: FAIL（`send` 未定义 / `_ControllableAssistant` 引用未实现的 ServerException import 等）。

补充 import：`import 'package:scho_navi/core/error/app_exception.dart';`（ServerException）。

- [ ] **Step 3: 实现 send + _slice**

在 `lib/features/preparation/providers/preparation_assistant_controller.dart` 的 `PreparationAssistantController` 内（`load` 之后）加：

```dart
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;
    final plan = _repo.findById(_planId);
    if (plan == null) return;
    final history = state.turns
        .slice(state.turns.length > 10 ? state.turns.length - 10 : 0)
        .map((t) => AssistantHistoryEntry(
              role: 'user',
              content: t.userMessage,
              cardResults: const <AssistantCardResult>[],
            ))
        .toList();
    final requestId = 'req_${DateTime.now().millisecondsSinceEpoch}';
    state = state.copyWith(sending: true);
    final request = PlanAssistantRequest(
      planId: _planId,
      calendarToday: CalendarDate.normalize(DateTime.now()),
      basePlanRevision: plan.revision,
      planSnapshot: plan,
      userMessage: trimmed,
      history: history,
      requestId: requestId,
    );
    final result = await _assistant.suggestChanges(request);
    switch (result) {
      case Success(:final data):
        final turn = AssistantTurn(
          id: 'turn_${DateTime.now().millisecondsSinceEpoch}',
          planId: _planId,
          userMessage: trimmed,
          reply: data.reply,
          createdAt: DateTime.now().toUtc(),
          cardStatuses: {for (final c in data.changeSet.cards) c.id: c.status},
          changeSet: data.changeSet,
          requestId: requestId,
        );
        await _store.append(_planId, turn);
        final latest = _repo.findById(_planId);
        state = state.copyWith(
          currentPlan: latest,
          sending: false,
          turns: [...state.turns, turn],
          expectedRevisions: {
            ...state.expectedRevisions,
            turn.id: data.changeSet.basePlanRevision,
          },
          cardStatuses: {
            ...state.cardStatuses,
            turn.id: {for (final c in data.changeSet.cards) c.id: c.status},
          },
        );
      case Failure():
        final turn = AssistantTurn(
          id: 'turn_${DateTime.now().millisecondsSinceEpoch}_err',
          planId: _planId,
          userMessage: trimmed,
          reply: '助手调用失败，请稍后重试。',
          createdAt: DateTime.now().toUtc(),
          cardStatuses: const {},
          error: true,
          requestId: requestId,
        );
        await _store.append(_planId, turn);
        state = state.copyWith(
          sending: false,
          turns: [...state.turns, turn],
        );
    }
  }
```

在文件末尾加 `_slice` 扩展：

```dart
extension _ListSlice<T> on List<T> {
  List<T> slice(int start) => start <= 0 ? List<T>.of(this) : sublist(start);
}
```

注意：不判 mounted（Notifier 无 mounted）。关闭抽屉后 `state = state.copyWith(...)` 仍执行，是预期行为（spec §4.2）。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/preparation/providers/preparation_assistant_controller_test.dart`
Expected: PASS（4 个测试 + load 测试）。

- [ ] **Step 5: analyze**

Run: `flutter analyze lib/features/preparation/providers/preparation_assistant_controller.dart`
Expected: No issues。

- [ ] **Step 6: Commit**

```bash
git add lib/features/preparation/providers/preparation_assistant_controller.dart test/features/preparation/providers/preparation_assistant_controller_test.dart
git commit -m "feat(preparation): 助手 controller send 关闭不取消"
```

---

## Task C.3：controller accept / decline / clearContext

**Files:**
- Modify: `lib/features/preparation/providers/preparation_assistant_controller.dart`（加 accept/decline/clearContext/_cascadeStale/_persistStatuses）
- Test: `test/features/preparation/providers/preparation_assistant_controller_test.dart`（追加）

**Interfaces:**
- Produces: `acceptCard(AssistantTurn turn, PlanChangeCard card)`、`declineCard(...)`、`clearContext()`。行为与搬迁前 drawer `_acceptCard`/`_declineCard`/`_cascadeStale`/`_persistStatuses` 完全一致。

- [ ] **Step 1: 写失败测试（clearContext）**

追加到 controller 测试。复用 `_ControllableAssistant`，先 send 出一张卡再 clear。需要一个带卡的 fake reply：

```dart
AssistantReply _replyWithAddCard() => const AssistantReply(
      reply: '加一次模拟答辩',
      changeSet: PlanChangeSet(
        id: 'cs_1',
        basePlanRevision: 1,
        cards: [
          PlanChangeCard(
            id: 'cc_add',
            type: ChangeCardType.addTask,
            targetPhaseKey: 'defense_prep',
            summary: '答辩准备阶段新增一次模拟答辩',
            rationale: '在正式答辩前预留复盘时间。',
            status: ChangeCardStatus.pending,
            newTask: NewTaskDraft(
              title: '第二次模拟答辩',
              estimatedHours: 3,
              dueDate: DateTime(2026, 6, 5),
            ),
          ),
        ],
      ),
      requestId: 'req_x',
    );
```

注意：`NewTaskDraft.dueDate` 是非空 `DateTime`（见 `lib/domain/entities/plan_change_card.dart:21,27`），测试必须给值。`PlanChangeCard`/`ChangeCardType`/`ChangeCardStatus` 来自 `package:scho_navi/domain/entities/plan_change_card.dart`。先 Read 该实体确认必填字段（`id`/`type`/`summary`/`rationale` 必填，`status` 默认 `pending`），再据此修正测试构造。

测试：

```dart
test('clearContext 清空 turns 但不删计划', () async {
  final completer = Completer<AssistantReply>();
  final fake = _ControllableAssistant(completer);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    initialAppConfigProvider.overrideWithValue(
      const AppConfig(dataSource: DataSource.llm, api: ApiConfig(baseUrl: 'https://fake.local')),
    ),
    preparationPlanAssistantProvider.overrideWithValue(fake),
  ]);
  addTearDown(container.dispose);
  await container.read(preparationPlanRepositoryProvider).save(_plan(revision: 0));

  final ctrl = container.read(preparationAssistantControllerProvider('pp_1'));
  await Future<void>.delayed(Duration.zero);

  ctrl.send('问');
  completer.complete(_replyWithAddCard());
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  expect(ctrl.state.turns, hasLength(1));

  await ctrl.clearContext();
  expect(ctrl.state.turns, isEmpty);
  expect(ctrl.state.cardStatuses, isEmpty);
  expect(ctrl.state.currentPlan, isNotNull); // 计划仍在
  final persisted = await container.read(assistantHistoryStoreProvider).list('pp_1');
  expect(persisted, isEmpty);
  expect(container.read(preparationPlanRepositoryProvider).findById('pp_1'), isNotNull);
});

test('sending 中 clearContext 被忽略', () async {
  final completer = Completer<AssistantReply>();
  final fake = _ControllableAssistant(completer);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    initialAppConfigProvider.overrideWithValue(
      const AppConfig(dataSource: DataSource.llm, api: ApiConfig(baseUrl: 'https://fake.local')),
    ),
    preparationPlanAssistantProvider.overrideWithValue(fake),
  ]);
  addTearDown(container.dispose);
  await container.read(preparationPlanRepositoryProvider).save(_plan(revision: 0));

  final ctrl = container.read(preparationAssistantControllerProvider('pp_1'));
  await Future<void>.delayed(Duration.zero);

  ctrl.send('问'); // sending
  await ctrl.clearContext(); // 应被忽略
  // store 仍可能有 load 之前的空，但 turns 不该被清空（本来也空）——
  // 关键：clearContext 在 sending 时不应触发 store.clear。
  expect(ctrl.state.sending, isTrue);
  completer.complete(const AssistantReply(
    reply: '答', changeSet: PlanChangeSet(id: 'cs_1', basePlanRevision: 1, cards: []),
  ));
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  expect(ctrl.state.turns, hasLength(1)); // send 仍完成
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/preparation/providers/preparation_assistant_controller_test.dart`
Expected: FAIL（`clearContext` 未定义）。

- [ ] **Step 3: 实现 accept/decline/clearContext**

在 controller 内（`send` 之后）加，逻辑原样搬迁自 `assistant_drawer.dart:178-293`，`setState` 改 `state = state.copyWith(...)`：

```dart
  Future<void> acceptCard(AssistantTurn turn, PlanChangeCard card) async {
    final statuses = state.cardStatuses[turn.id];
    if (statuses == null) return;
    final current = statuses[card.id] ?? card.status;
    if (current == ChangeCardStatus.applied) return;
    if (current != ChangeCardStatus.pending) return;
    if (state.applying.contains(card.id)) return;

    state = state.copyWith(
      applying: {...state.applying, card.id},
      cardErrors: {...state.cardErrors}..remove(card.id),
    );

    final latest = _repo.findById(_planId);
    if (latest == null) {
      state = state.copyWith(
        applying: state.applying..remove(card.id),
        cardErrors: {...state.cardErrors, card.id: '计划不存在'},
      );
      return;
    }
    final expectedRevision =
        state.expectedRevisions[turn.id] ?? turn.changeSet!.basePlanRevision;

    if (latest.revision != expectedRevision) {
      final next = Map<String, ChangeCardStatus>.from(statuses);
      _cascadeStale(turn, next);
      state = state.copyWith(
        cardStatuses: {...state.cardStatuses, turn.id: next},
        applying: state.applying..remove(card.id),
      );
      await _persistStatuses(turn, next);
      return;
    }

    final result = PlanChangeApplier.applyCard(
      plan: latest,
      card: card,
      expectedRevision: expectedRevision,
    );

    if (result.stale) {
      final next = Map<String, ChangeCardStatus>.from(statuses);
      _cascadeStale(turn, next);
      state = state.copyWith(
        cardStatuses: {...state.cardStatuses, turn.id: next},
        applying: state.applying..remove(card.id),
      );
      await _persistStatuses(turn, next);
      return;
    }
    if (!result.applied) {
      state = state.copyWith(
        cardErrors: {...state.cardErrors, card.id: result.error ?? '应用失败'},
        applying: state.applying..remove(card.id),
      );
      await _persistStatuses(turn, statuses);
      return;
    }

    try {
      final saved = await _repo.save(result.newPlan!);
      state = state.copyWith(
        cardStatuses: {
          ...state.cardStatuses,
          turn.id: {...statuses, card.id: ChangeCardStatus.applied},
        },
        expectedRevisions: {
          ...state.expectedRevisions,
          turn.id: saved.revision,
        },
        applying: state.applying..remove(card.id),
        currentPlan: saved,
      );
      await _persistStatuses(turn, state.cardStatuses[turn.id]!);
    } on ConflictException {
      state = state.copyWith(
        cardErrors: {...state.cardErrors, card.id: '数据已变化，请刷新后重试'},
        applying: state.applying..remove(card.id),
      );
    }
  }

  void _cascadeStale(AssistantTurn turn, Map<String, ChangeCardStatus> statuses) {
    for (final c in turn.changeSet!.cards) {
      final s = statuses[c.id] ?? c.status;
      if (s == ChangeCardStatus.pending) {
        statuses[c.id] = ChangeCardStatus.stale;
      }
    }
  }

  Future<void> declineCard(AssistantTurn turn, PlanChangeCard card) async {
    final statuses = state.cardStatuses[turn.id];
    if (statuses == null) return;
    final current = statuses[card.id] ?? card.status;
    if (current != ChangeCardStatus.pending &&
        current != ChangeCardStatus.declined) {
      return;
    }
    final next = Map<String, ChangeCardStatus>.from(statuses);
    next[card.id] = current == ChangeCardStatus.declined
        ? ChangeCardStatus.pending
        : ChangeCardStatus.declined;
    state = state.copyWith(
      cardStatuses: {...state.cardStatuses, turn.id: next},
    );
    await _persistStatuses(turn, next);
  }

  Future<void> _persistStatuses(
    AssistantTurn turn,
    Map<String, ChangeCardStatus> statuses,
  ) async {
    await _store.updateCardStatuses(_planId, turn.id, statuses);
  }

  Future<void> clearContext() async {
    if (state.sending) return;
    await _store.clear(_planId);
    state = state.copyWith(
      turns: const [],
      expectedRevisions: const {},
      cardStatuses: const {},
      applying: const {},
      cardErrors: const {},
    );
  }
```

注意：`PlanChangeApplier` 来自 `package:scho_navi/domain/services/plan_change_applier.dart`，需 import。确认 `applyCard` 返回类型有 `.stale`/`.applied`/`.error`/`.newPlan` 字段（搬迁自 drawer，应一致）。

import 区加：
```dart
import '../../../domain/services/plan_change_applier.dart';
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/preparation/providers/preparation_assistant_controller_test.dart`
Expected: PASS（含 clearContext 两个测试）。

- [ ] **Step 5: analyze**

Run: `flutter analyze lib/features/preparation/providers/preparation_assistant_controller.dart`
Expected: No issues。

- [ ] **Step 6: Commit**

```bash
git add lib/features/preparation/providers/preparation_assistant_controller.dart test/features/preparation/providers/preparation_assistant_controller_test.dart
git commit -m "feat(preparation): 助手 controller accept/decline/clearContext"
```

---

# Phase D：抽屉改薄 + 清理入口

> 依赖：C。把 drawer 改为读 controller，并加「清理上下文」入口。**现有 8 个 assistant_drawer_test.dart 必须继续通过**（它们经 widget 驱动 controller）。

## Task D.1：抽屉改读 controller + 清理上下文入口

**Files:**
- Modify: `lib/features/preparation/widgets/assistant_drawer.dart`（全文重写为 controller 视图）
- Test: `test/features/preparation/widgets/assistant_drawer_test.dart`（追加清理上下文 + 关闭不丢失测试；既有 8 测试保持）

**Interfaces:**
- Consumes: `preparationAssistantControllerProvider(planId)`
- Produces: `PreparationAssistantDrawer` 仍为 `ConsumerWidget`（或保留 StatefulWidget 仅持 `_input`/`_scroll`），构造仍 `{required String planId, required PreparationPlan plan}`

- [ ] **Step 1: 追加关闭不丢失 + 清理上下文测试**

追加到 `test/features/preparation/widgets/assistant_drawer_test.dart`（用既有 `_bootstrap`/`_harness` helper）：

```dart
  testWidgets('关闭抽屉后请求完成，重开可见该轮回复', (t) async {
    final container = await _bootstrap();
    await t.pumpWidget(_harness(container));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '关抽屉测试');
    await t.pump();
    await t.tap(find.byIcon(Icons.arrow_upward));
    // 不等完成——模拟用户立刻关抽屉。
    await t.pump(const Duration(milliseconds: 10));

    // 重新挂载（模拟重开）：controller 非 autoDispose，state 存活。
    await t.pumpWidget(_harness(container));
    await t.pumpAndSettle();

    expect(find.textContaining('我整理了两项可单独确认的调整'), findsOneWidget);
    expect(find.textContaining('关抽屉测试'), findsOneWidget);
  });

  testWidgets('清理上下文清空历史但计划仍在', (t) async {
    final container = await _bootstrap(savePlan: true);
    await t.pumpWidget(_harness(container));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '第一轮');
    await t.pump();
    await t.tap(find.byIcon(Icons.arrow_upward));
    await t.pumpAndSettle();
    expect(find.textContaining('第一轮'), findsOneWidget);

    // 点清理上下文图标。
    await t.tap(find.byIcon(Icons.cleaning_services_outlined));
    await t.pumpAndSettle();
    // 二次确认。
    await t.tap(find.text('清理'));
    await t.pumpAndSettle();

    // 历史清空。
    expect(find.textContaining('第一轮'), findsNothing);
    expect(find.textContaining('我整理了两项可单独确认的调整'), findsNothing);
    // 计划仍在。
    expect(
      container.read(preparationPlanRepositoryProvider).findById('pp_1'),
      isNotNull,
    );
    // store 清空。
    final persisted =
        await container.read(assistantHistoryStoreProvider).list('pp_1');
    expect(persisted, isEmpty);
  });

  testWidgets('发送中清理上下文按钮禁用', (t) async {
    final container = await _bootstrap();
    await t.pumpWidget(_harness(container));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '发送中');
    await t.pump();
    await t.tap(find.byIcon(Icons.arrow_upward));
    await t.pump(const Duration(milliseconds: 10)); // sending 中

    final clearBtn = t.widget<IconButton>(
      find.byIcon(Icons.cleaning_services_outlined),
    );
    expect(clearBtn.onPressed, isNull);
  });
```

注意：抽屉仍是 modal sheet 内 widget，但测试 `_harness` 直接把 drawer 放在 Scaffold body（既有测试模式），所以 `Navigator.of(context).maybePop()` 在非 sheet 场景的关闭按钮不影响本测试。清理入口用 `IconButton(Icons.cleaning_services_outlined)`。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/preparation/widgets/assistant_drawer_test.dart`
Expected: FAIL（清理图标未实现 / controller 未接入）。

- [ ] **Step 3: 重写抽屉为 controller 视图**

`lib/features/preparation/widgets/assistant_drawer.dart` 改为读 controller。保留 `_input`/`_scroll` 在 Stateful 内，其余状态从 controller 读。完整重写：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/assistant_turn.dart';
import '../../../domain/entities/plan_change_card.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../providers/preparation_assistant_controller.dart';
import '../../chat/widgets/chat_message_bubble.dart';
import '../widgets/assistant_turn_message_mapper.dart';
import '../widgets/plan_change_card_view.dart';

class PreparationAssistantDrawer extends ConsumerStatefulWidget {
  const PreparationAssistantDrawer({
    super.key,
    required this.planId,
    required this.plan,
  });

  final String planId;
  final PreparationPlan plan;

  @override
  ConsumerState<PreparationAssistantDrawer> createState() =>
      _PreparationAssistantDrawerState();
}

class _PreparationAssistantDrawerState
    extends ConsumerState<PreparationAssistantDrawer> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _input.text;
    _input.clear();
    await ref
        .read(preparationAssistantControllerProvider(widget.planId))
        .send(text);
    _scrollToBottom();
  }

  bool get _canSubmit => _input.text.trim().isNotEmpty && !_sending;

  bool get _sending =>
      ref.read(preparationAssistantControllerProvider(widget.planId)).state.sending;

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(preparationAssistantControllerProvider(widget.planId));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _Header(
              title: state.currentPlan?.competition.name ?? widget.plan.competition.name,
              sending: state.sending,
              onClear: () => _confirmClear(context),
            ),
            Expanded(child: _buildConversation(state)),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation(PreparationAssistantControllerState state) {
    final messages = <Widget>[];
    for (final turn in state.turns) {
      final pair = AssistantTurnMessageMapper.toMessages(turn, widget.planId);
      messages.add(Padding(
        key: ValueKey('${turn.id}_user'),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ChatMessageBubble(message: pair[0], onTapRecommendation: (_) {}),
      ));
      messages.add(Padding(
        key: ValueKey('${turn.id}_assistant'),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ChatMessageBubble(message: pair[1], onTapRecommendation: (_) {}),
      ));
      if (!turn.error && turn.changeSet != null) {
        messages.add(_ChangeCardRow(
          key: ValueKey('${turn.id}_cards'),
          turn: turn,
          cards: turn.changeSet!.cards,
          statuses: state.cardStatuses[turn.id] ?? const {},
          applying: state.applying,
          errors: state.cardErrors,
          onAccept: (card) => ref
              .read(preparationAssistantControllerProvider(widget.planId))
              .acceptCard(turn, card),
          onDecline: (card) => ref
              .read(preparationAssistantControllerProvider(widget.planId))
              .declineCard(turn, card),
        ));
      }
    }
    if (state.sending) {
      messages.add(const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ));
    }
    if (messages.isEmpty) {
      messages.add(_buildEmptyHint());
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: messages,
    );
  }

  Widget _buildEmptyHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          Icon(Icons.auto_awesome, size: 36, color: AppColors.indigo),
          const SizedBox(height: 12),
          Text(
            '告诉助手你想怎么调整计划',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: !_sending,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: '输入你的调整需求…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _canSubmit ? AppColors.indigo : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _canSubmit ? _send : null,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_upward,
                  color: _canSubmit ? Colors.white : AppColors.inkSoft,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final state =
        ref.read(preparationAssistantControllerProvider(widget.planId)).state;
    if (state.sending) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清理上下文'),
        content: const Text('清理上下文会清空本计划的助手对话历史，但不删除计划本身。确认清理？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(preparationAssistantControllerProvider(widget.planId))
        .clearContext();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.sending, required this.onClear});
  final String title;
  final bool sending;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 20, color: AppColors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI 助手',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(title,
                    style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: '清理上下文',
            onPressed: sending ? null : onClear,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _ChangeCardRow extends StatelessWidget {
  const _ChangeCardRow({
    super.key,
    required this.turn,
    required this.cards,
    required this.statuses,
    required this.applying,
    required this.errors,
    required this.onAccept,
    required this.onDecline,
  });

  final AssistantTurn turn;
  final List<PlanChangeCard> cards;
  final Map<String, ChangeCardStatus> statuses;
  final Set<String> applying;
  final Map<String, String> errors;
  final ValueChanged<PlanChangeCard> onAccept;
  final ValueChanged<PlanChangeCard> onDecline;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final card = cards[i];
          return PlanChangeCardView(
            key: ValueKey('${turn.id}_${card.id}'),
            card: card,
            status: statuses[card.id] ?? card.status,
            errorMessage: errors[card.id],
            applying: applying.contains(card.id),
            onAccept: () => onAccept(card),
            onDecline: () => onDecline(card),
          );
        },
      ),
    );
  }
}
```

注意：
- 既有测试 `_bootstrap` 未 `savePlan` 时，`currentPlan` 可能为 null（controller load 读 repo findById 返回 null），`_Header` title 用 `widget.plan.competition.name` 兜底。既有 8 测试不依赖 controller 的 currentPlan，依赖 fake handler 渲染卡片——send 后 controller 落盘 turn，UI 经 `state.turns` 渲染，与既有断言一致。
- 既有测试 `_bootstrap` 不 savePlan 但发送成功，是因为 fake handler 返回固定卡。controller send 用 `_repo.findById` 读 plan：若 repo 无 plan（未 savePlan），`send` 第 5 行 `if (plan == null) return;` 会**直接返回不发送**——这会让既有「发送消息后渲染 AI 回复」测试失败！

**关键修正**：既有测试 `_bootstrap()`（savePlan: false）依赖发送能成功。controller send 读 `findById`，未 savePlan 时返回 null。两种解法：
1. 既有测试改为默认 savePlan（改 `_bootstrap` 默认 `savePlan: true`）。但这会动既有测试 helper。
2. controller send 在 `findById` 为 null 时回退用 `widget.plan`——但 controller 不持有 widget。

**采用方案 1**：本 Task 修改既有测试 `_bootstrap` 的默认 `savePlan` 为 `true`，并在不希望 savePlan 的用例显式传 `savePlan: false`。检查既有 8 测试哪些依赖未 savePlan：
- 「发送消息后渲染 AI 回复」`_bootstrap()` → 需 savePlan。
- 「改动卡渲染…」`_bootstrap()` → 需 savePlan。
- 「自定义 plan id 须显式注册」`_bootstrap(planId: 'pp_custom')` → 走 404 Failure，是否 savePlan 不影响 Failure 渲染，但 controller send 在 plan==null 时 return 会导致不发送、不渲染失败态！**需 savePlan**。
- 「注册自定义 plan id 后可正常返回卡片」`_bootstrap(planId: 'pp_custom', registerCustomPlanId: true)` → 需 savePlan。
- 「历史轮次渲染」`_bootstrap()` → 需 savePlan。
- 「接受 addTask」已 `savePlan: true`。
- 「拒绝后卡标 declined」已 `savePlan: true`。
- 其余 deleteTask/stale/conflict/idempotent 自带 repo override 或 savePlan。

因此把 `_bootstrap` 默认 `savePlan: true`：

修改 `_bootstrap`（line 74-108）签名默认 `bool savePlan = true`。然后「自定义 plan id 须显式注册」用例（line 173-188）验证 404：savePlan 后 fake handler 未注册 `pp_custom`，发送走 Failure 渲染错误态——与既有断言一致（`生成失败` + 无卡片）。

**注意 savePlan 用 `_plan(id: planId, revision: 0)`**：`_bootstrap` 已有此逻辑（line 100-106），savePlan 默认改 true 即可生效。

修改既有 `_bootstrap` 默认值：

```dart
Future<ProviderContainer> _bootstrap({
  String planId = 'pp_1',
  bool registerCustomPlanId = false,
  bool savePlan = true,
}) async {
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/preparation/widgets/assistant_drawer_test.dart`
Expected: PASS（既有 8 + 新增 3）。若既有测试因 controller load 异步时序失败（如「发送后渲染」在 send 完成前断言），确认 `t.pumpAndSettle()` 等待 controller 的 microtask + fake http 完成。既有用 `pumpAndSettle` 应能等到。

若「关闭抽屉后请求完成」测试因 modal sheet 重挂载时序不稳定，改用：先 `pump` 触发 send，再 `pumpWidget` 重挂载，再 `pumpAndSettle`。已在测试中处理。

- [ ] **Step 5: analyze**

Run: `flutter analyze lib/features/preparation/widgets/assistant_drawer.dart`
Expected: No issues。

- [ ] **Step 6: 回归周边测试**

Run: `flutter test test/features/preparation/ test/features/chat/`
Expected: PASS（chat 不受影响；preparation 详情页测试在 Phase E 改）。

- [ ] **Step 7: Commit**

```bash
git add lib/features/preparation/widgets/assistant_drawer.dart test/features/preparation/widgets/assistant_drawer_test.dart
git commit -m "feat(preparation): 助手抽屉改读 controller+清理上下文入口"
```

---

# Phase E：详情页 AppBar 收敛

> 依赖：无（独立，可最后做）。

## Task E.1：移除日历图标，并入 PopupMenu

**Files:**
- Modify: `lib/features/preparation/pages/preparation_plan_detail_page.dart:232-253`
- Test: `test/features/preparation/pages/preparation_plan_detail_page_test.dart`（追加 AppBar 断言）

**Interfaces:**
- 无新接口；`_changeTargetDate`/`PreparationPlanDetailRescheduler` 不动

- [ ] **Step 1: 写失败测试**

追加到 `test/features/preparation/pages/preparation_plan_detail_page_test.dart`（先 Read 该测试文件确认 harness helper 名称）：

```dart
  testWidgets('AppBar 无日历图标，PopupMenu 含调整目标日期', (t) async {
    final container = await _bootstrap(); // 复用既有 helper
    await t.pumpWidget(_harness(container)); // 复用既有 harness
    await t.pumpAndSettle();

    expect(find.byIcon(Icons.event_outlined), findsNothing);
    // 打开 PopupMenu。
    await t.tap(find.byType(PopupMenuButton<String>));
    await t.pumpAndSettle();
    expect(find.text('调整目标日期'), findsOneWidget);
    expect(find.text('归档计划'), findsOneWidget);
    expect(find.text('删除计划'), findsOneWidget);
  });
```

注意：先 Read `test/features/preparation/pages/preparation_plan_detail_page_test.dart` 确认其 `_bootstrap`/`_harness`/`_pumpPage` 等实际命名与是否需 savePlan。按既有 helper 调整上述调用。若既有无 helper，参照 assistant_drawer_test 的 `_bootstrap`/`_harness` 模式新建最小 harness（savePlan 一个 plan，pump `PreparationPlanDetailPage(planId: ...)`）。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/preparation/pages/preparation_plan_detail_page_test.dart`
Expected: FAIL（仍有 `event_outlined` / PopupMenu 无「调整目标日期」）。

- [ ] **Step 3: 改 AppBar**

修改 `lib/features/preparation/pages/preparation_plan_detail_page.dart` line 232-253 的 `appBar: AppBar(...)` actions：

```dart
      appBar: AppBar(
        title: Text(plan.competition.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'targetDate') {
                _changeTargetDate(plan);
              } else if (v == 'archive') {
                _confirmArchive(plan);
              } else if (v == 'delete') {
                _confirmDelete(plan);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'targetDate', child: Text('调整目标日期')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'archive', child: Text('归档计划')),
              PopupMenuItem(value: 'delete', child: Text('删除计划')),
            ],
          ),
        ],
      ),
```

删除原 `IconButton(icon: const Icon(Icons.event_outlined), ...)`。`_changeTargetDate` 完全不动。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/preparation/pages/preparation_plan_detail_page_test.dart`
Expected: PASS（新测试 + 既有归档/删除/任务测试）。

- [ ] **Step 5: analyze + a11y 回归**

Run: `flutter analyze lib/features/preparation/pages/preparation_plan_detail_page.dart`
Expected: No issues。

Run: `flutter test test/features/preparation/pages/preparation_plan_detail_page_a11y_test.dart`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/features/preparation/pages/preparation_plan_detail_page.dart test/features/preparation/pages/preparation_plan_detail_page_test.dart
git commit -m "feat(preparation): 详情页日期入口并入更多菜单"
```

---

# Phase F：契约收口与全量验证

## Task F.1：targeted 全量 + analyze + 后端

**Files:**
- 无（仅验证）

- [ ] **Step 1: targeted flutter test**

Run: `flutter test test/features/preparation/ test/features/chat/ test/domain/ test/data/local/ test/data/ai/ test/data/http/ test/data/dto/ test/data/mock/ test/core/`
Expected: 全 PASS。

- [ ] **Step 2: analyze**

Run: `flutter analyze`
Expected: No issues。

- [ ] **Step 3: 全量 flutter test（Drift hang 已知问题）**

Run: `flutter test`
Expected: 备赛/助手/chat 相关全绿。若 Drift 测试 hang（既有问题，非本次引入），明确说明哪些通过、哪些 hang，不强行绕过。

- [ ] **Step 4: 后端测试**

Run: `cd web/backend && uv run python -m pytest -q`
Expected: 全 PASS（含 assistant 4 测试 + 既有）。

- [ ] **Step 5: 上机肉眼验证（如可行）**

Run: `flutter run`，验证：
1. 详情页右上更多菜单含「调整目标日期」，点击触发原重排流程；顶部无日历图标。
2. 助手发消息→关抽屉→重开见该轮回复+卡。
3. 发送中禁再次发送与清理上下文（清理图标灰）。
4. 清理上下文清空历史但计划仍在。
5. HTTP 模式：启动 FastAPI 后端，App 切 HTTP 数据源，助手不再 404。

无法上机的项逐项明确说明。

- [ ] **Step 6: 若有测试微调，最终 commit**

```bash
git add -A
git commit -m "test(preparation): 助手会话优化回归"
```

---

## Spec 覆盖自检（实现完成后逐条核对）

- §1 背景四点 → Task E.1（AppBar）/ D.1（关闭不丢失）/ D.1（清理上下文）/ B.2+B.3（HTTP 端点）
- §2.1 做 → 全 phase 覆盖
- §2.2 不做 → 全程未引入多会话/迁移/running 态/启动扫描
- §3.1 DTO requestId → Task A.1
- §3.2 AssistantTurn requestId → Task A.2
- §3.3 假后端 echo → Task A.4
- §3.4 OpenAPI → Task A.5
- §3.5 FastAPI 端点 → Task B.1/B.2/B.3
- §3.6 客户端最终校验不变 → controller accept 搬迁，validator/applier/CAS 不动
- §4.1 controller state → Task C.1
- §4.2 send 关闭不取消 + 读最新 + 失败落盘 → Task C.2
- §4.3 accept/decline 搬迁 → Task C.3
- §4.4 clearContext → Task C.3
- §5.1 AppBar 收敛 → Task E.1
- §5.2 抽屉改薄 → Task D.1
- §5.3 清理入口 → Task D.1
- §5.4 发送中禁用 → Task D.1（_Header 禁用 + 输入框 enabled）
- §6 测试策略 → 各 Task 内 + Phase F
- §7 文件清单 → 全覆盖
- §8 实现分期 → A→B→C→D→E→F 顺序
