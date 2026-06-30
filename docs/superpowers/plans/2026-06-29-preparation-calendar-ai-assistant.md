# 备赛功能升级：智能备赛日历 + AI 助手 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把备赛功能从「一次性生成 + 手工改」升级为「智能备赛日历 + 随时唤出的 AI 助手」，覆盖双段时间模型、水平诊断、结构化改动卡逐条应用，并对齐 ChatGPT 式无气泡 AI 回复。

**Architecture:** 客户端确定性（排期/校验/写入由 Dart 负责），AI 只提议。新增双段时间模型（窗口型/提交型）、水平画像独立 store、改动卡草稿 DTO + 共享 validator + compare-and-set 仓库、助手历史独立 store。三端点（diagnose / generate / assistant）各走 LLM/HTTP/Fake 三路径，共用 DTO 校验器。

**Tech Stack:** Flutter/Dart, flutter_riverpod, go_router, dio, shared_preferences, gpt_markdown, flutter_svg。不引入新依赖。

## Global Constraints

- 日期协议：`targetDate`/`eventEndDate`/`defenseDate`/阶段起止/`dueDate` 是无时区日历日期，Dart 内规范化为 `DateTime(y,m,d)`，JSON 用 `YYYY-MM-DD`（`format: date`）；`createdAt`/`updatedAt`/`diagnosedAt` 用 UTC RFC 3339 `date-time`。
- `calendar_today` 是本次本地操作的权威日历基准，后端只校验格式与顺序，不用服务器时区替换。
- 所有日期区间为闭区间；新建计划 `targetDate > calendarToday`。
- AI 不得编造竞赛/教授/证据数据；改动卡只能引用快照中已存在的 `taskId`/`phaseKey`。
- 改动卡一次最多 5 张；`deleteTask` 仅允许 `optional`/`userAdded`；必做任务只能 `moveTask` 移日期。
- 保留中文产品文案风格；默认无注释，仅在不明显处加短注释。
- 不引入新状态管理/路由/持久化/HTTP 第三方库；持久化仍用 `LocalStore`/SharedPreferences。
- 每期独立可验证：先 targeted `flutter test`，再 `flutter analyze`，UI 改动上机肉眼验证。
- 提交规范：`feat(preparation): ...` / `feat(chat): ...` / `test(preparation): ...` / `docs(api): ...`。不提交 API key。

**Spec:** [docs/superpowers/specs/2026-06-29-preparation-calendar-ai-assistant-design.md](../specs/2026-06-29-preparation-calendar-ai-assistant-design.md)

---

## File Structure（新增 / 修改总览）

**新增领域实体与服务：**
- `lib/domain/entities/preparation_plan.dart`（修改：加 timelineType/eventEndDate/defenseDate/revision + LevelDiagnosis 相关移出）
- `lib/domain/entities/level_diagnosis.dart`（新）
- `lib/domain/entities/plan_change_card.dart`（新）
- `lib/domain/entities/competition_timeline_defaults.dart`（新）
- `lib/domain/services/preparation_scheduler.dart`（修改：分段排期）
- `lib/domain/services/preparation_plan_generator.dart`（修改：双段生成）
- `lib/domain/services/plan_change_applier.dart`（新）
- `lib/domain/services/competition_category_normalizer.dart`（新）

**新增数据层：**
- `lib/data/local/local_preparation_plan_repository.dart`（修改：v2 迁移 + compare-and-set）
- `lib/data/local/local_preparation_template_provider.dart`（修改：按 timelineType 加载）
- `lib/data/local/level_diagnosis_store.dart`（新）
- `lib/data/local/assistant_history_store.dart`（新）
- `lib/data/fixtures/preparation_templates.dart`（修改：双骨架）
- `lib/data/fixtures/competition_timeline_defaults.dart`（新，fixture 别名）
- `lib/data/dto/preparation_plan_dtos.dart`（修改：generate 入参扩展）
- `lib/data/dto/level_diagnosis_dtos.dart`（新）
- `lib/data/dto/plan_change_card_dtos.dart`（新）
- `lib/data/ai/ai_preparation_personalizer.dart`（修改：prompt 扩展）
- `lib/data/ai/ai_preparation_level_diagnoser.dart`（新）
- `lib/data/ai/ai_preparation_plan_assistant.dart`（新）
- `lib/data/http/http_preparation_level_diagnoser.dart`（新）
- `lib/data/http/http_preparation_plan_assistant.dart`（新）
- `lib/data/mock/fake_preparation_backend.dart`（修改：加 diagnose/assistant handler）
- `lib/data/mock/fake_preparation_diagnose_backend.dart`（新）
- `lib/data/mock/fake_preparation_assistant_backend.dart`（新）
- `lib/core/calendar_date.dart`（新：日历日期 codec）
- `lib/core/error/app_exception.dart`（修改：加 ConflictException）

**新增领域接口：**
- `lib/domain/repositories/preparation_template_provider.dart`（修改：load 签名）
- `lib/domain/repositories/preparation_level_diagnoser.dart`（新）
- `lib/domain/repositories/preparation_plan_assistant.dart`（新）
- `lib/domain/repositories/preparation_plan_repository.dart`（修改：save 加 expectedRevision）

**新增 UI：**
- `lib/features/chat/widgets/chat_message_bubble.dart`（修改：P0 气泡拆分）
- `lib/features/preparation/widgets/preparation_date_picker.dart`（新）
- `lib/features/preparation/widgets/preparation_anchor_bar.dart`（新）
- `lib/features/preparation/widgets/plan_change_card_view.dart`（新）
- `lib/features/preparation/widgets/assistant_drawer.dart`（新）
- `lib/features/preparation/widgets/assistant_turn_message_mapper.dart`（新）
- `lib/features/preparation/pages/preparation_plan_form_page.dart`（修改：向导）
- `lib/features/preparation/pages/preparation_plan_detail_page.dart`（修改：锚点条 + 助手入口 + 手工语义）
- `lib/features/preparation/providers/preparation_providers.dart`（修改：新 provider）

**文档：**
- `docs/openapi.yaml`（修改）
- `docs/api-contract.md`（修改）
- `assets/preparation_templates/competition_overrides.json`（修改：ICPC/蓝桥杯迁移）

---

# Phase P0：聊天气泡拆分

> 依赖：无。最先做，备赛 AI 助手复用。

## Task P0.1：AI 回复去气泡 + 行距常量

**Files:**
- Modify: `lib/features/chat/widgets/chat_message_bubble.dart:36-101`
- Test: `test/features/chat/chat_message_bubble_test.dart`

**Interfaces:**
- Produces: `ChatMessageBubble` 仍接受 `ChatMessage`；新增公开静态常量 `ChatMessageBubble.assistantLineHeight`（double，供测试读取）

**背景：** 当前 [chat_message_bubble.dart:92-101](lib/features/chat/widgets/chat_message_bubble.dart#L92-L101) 对用户和 AI 消息都套同一个 `Container`（圆角+背景+`maxWidth: min(360, 宽×0.78)`），AI 回复被压到 78% 宽频繁换行。需拆分：用户保留气泡，AI 全宽无气泡。

- [ ] **Step 1: 写失败测试（AI 无气泡、用户有气泡）**

追加到 `test/features/chat/chat_message_bubble_test.dart` 的 `main()` 内（在已有 test 之后）：

```dart
testWidgets('助手正常回复无气泡容器(全宽透明)', (tester) async {
  await _pump(
    tester,
    _msg(
      role: ChatRole.assistant,
      content: '这是一段较长的助手回复，应当全宽显示而不被气泡收窄',
      status: ChatMessageStatus.done,
    ),
  );
  await tester.pumpAndSettle();

  // 助手消息不应再有带背景色的圆角 Container 气泡
  final containers = tester
      .widgetList<Container>(find.byType(Container))
      .where((c) => c.decoration is BoxDecoration);
  final bubbleContainers = containers.where((c) {
    final box = c.decoration as BoxDecoration;
    return box.color != null && box.borderRadius != null;
  });
  expect(bubbleContainers, isEmpty,
      reason: '助手回复不应有带背景色的圆角气泡');
  expect(find.byType(GptMarkdown), findsOneWidget);
});

testWidgets('用户消息仍保留气泡', (tester) async {
  await _pump(
    tester,
    _msg(
      role: ChatRole.user,
      content: '用户消息',
      status: ChatMessageStatus.done,
    ),
  );
  await tester.pumpAndSettle();

  final containers = tester
      .widgetList<Container>(find.byType(Container))
      .where((c) => c.decoration is BoxDecoration);
  final bubble = containers.where((c) {
    final box = c.decoration as BoxDecoration;
    return box.color != null && box.borderRadius != null;
  });
  expect(bubble, isNotEmpty, reason: '用户消息应保留气泡');
});

testWidgets('助手回复行高常量可读取且大于0', (tester) async {
  expect(ChatMessageBubble.assistantLineHeight, greaterThan(0));
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/chat/chat_message_bubble_test.dart`
Expected: 3 个新测试 FAIL（`assistantLineHeight` 未定义 / 气泡仍存在）

- [ ] **Step 3: 实现 AI 去气泡 + 行距常量**

修改 `lib/features/chat/widgets/chat_message_bubble.dart`。在 `class ChatMessageBubble` 内（`build` 之前）加公开常量：

```dart
  /// AI 回复正文统一行高（spec §4.6 可测试常量），上机后微调。
  static const double assistantLineHeight = 1.4;
```

然后把 `build` 内构造 `body` 的部分与外层 `Container` 拆成两条分支。把当前第 59-101 行的 `body`/`content`/`selectableContent` 与外层 `Container` 替换为：

```dart
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == ChatRole.user;
    final isError =
        message.status == ChatMessageStatus.error ||
        message.status == ChatMessageStatus.interrupted;
    final isStreaming = message.status == ChatMessageStatus.streaming;

    final assistantStyle = DefaultTextStyle.of(context).style.copyWith(
          height: ChatMessageBubble.assistantLineHeight,
        );

    final Widget body;
    if (isError) {
      body = _AssistantErrorView(
        message: message,
        onRetry: onRegenerate == null ? null : () => onRegenerate!(message.id),
      );
    } else if (isUser) {
      body = Text(message.content);
    } else {
      body = DefaultTextStyle(
        style: assistantStyle,
        child: GptMarkdown(message.content),
      );
    }

    final Widget content = (isStreaming && !isError)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              body,
              const SizedBox(height: 6),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 6),
                  Text('生成中…', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          )
        : body;
    // 仅用户消息保留可选中区域（错误态由 _AssistantErrorView 自管）。
    final Widget selectableContent = isUser
        ? content
        : (isError ? content : SelectionArea(child: content));

    final double maxWidth =
        math.min(360.0, MediaQuery.sizeOf(context).width * 0.78);

    final Widget messageBody = isUser
        ? Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: selectableContent,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: selectableContent,
          );
```

然后在 `return Column(...)` 里，把原来的 `Container(...)` 子节点替换为 `messageBody`。Column 的 `crossAxisAlignment` 保持 `isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start`。

注意：删掉旧的 `bubbleColor`、`maxWidth`（旧位置）等不再使用的局部变量，避免 analyze 警告。`math` import（`dart:math`）仍需保留（maxWidth 用到）。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/chat/chat_message_bubble_test.dart`
Expected: 旧测试 + 3 个新测试全 PASS。

注意：旧测试 `错误消息用纯文本展示文案`（line 144）断言 `find.text('服务异常，请稍后重试')`，会被下一 Task P0.2 改为错误态视图，**本步先让它通过**——`_AssistantErrorView` 暂时把 message.content 直接显示成文本即可（见 Step 3 占位）。但为了不让该旧测试在 P0.2 才改，本步 `_AssistantErrorView` 先这样写（临时，P0.2 重写）：

```dart
class _AssistantErrorView extends StatelessWidget {
  const _AssistantErrorView({required this.message, this.onRetry});
  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // P0.2 会重写为圆圈红感叹号 + 查看详情。
    return Text(message.content);
  }
}
```

放在文件末尾（`_ActionButton` class 之后）。

- [ ] **Step 5: 运行 analyze**

Run: `flutter analyze lib/features/chat/widgets/chat_message_bubble.dart`
Expected: No issues。

- [ ] **Step 6: Commit**

```bash
git add lib/features/chat/widgets/chat_message_bubble.dart test/features/chat/chat_message_bubble_test.dart
git commit -m "feat(chat): AI 回复去气泡全宽 + 行距常量"
```

---

## Task P0.2：AI 错误态（圆圈红感叹号 + 查看详情 + 重试）

**Files:**
- Modify: `lib/features/chat/widgets/chat_message_bubble.dart`（`_AssistantErrorView`）
- Test: `test/features/chat/chat_message_bubble_test.dart`

**Interfaces:**
- Produces: `_AssistantErrorView` 展示圆圈红感叹号 + 错误文案 +「查看详情」展开 +「重试」

- [ ] **Step 1: 改写错误态测试**

把 `test/features/chat/chat_message_bubble_test.dart` 里 `错误消息用纯文本展示文案`（line 144-156）替换为：

```dart
testWidgets('助手错误态显示圆圈红感叹号与查看详情', (tester) async {
  await _pump(
    tester,
    _msg(
      role: ChatRole.assistant,
      content: '服务异常，请稍后重试',
      status: ChatMessageStatus.error,
    ),
  );
  await tester.pumpAndSettle();

  // 圆圈红感叹号图标
  expect(find.byIcon(Icons.error_outline), findsOneWidget);
  // 默认折叠，不直接展示错误文案
  expect(find.text('服务异常，请稍后重试'), findsNothing);
  // 「查看详情」按钮存在
  expect(find.text('查看详情'), findsOneWidget);
});

testWidgets('点击查看详情展开错误文案', (tester) async {
  await _pump(
    tester,
    _msg(
      role: ChatRole.assistant,
      content: '服务异常，请稍后重试',
      status: ChatMessageStatus.error,
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('查看详情'));
  await tester.pumpAndSettle();

  expect(find.text('服务异常，请稍后重试'), findsOneWidget);
});

testWidgets('错误态有重试按钮回调', (tester) async {
  String? retried;
  await _pump(
    tester,
    _msg(
      role: ChatRole.assistant,
      content: '服务异常，请稍后重试',
      status: ChatMessageStatus.error,
    ),
    onRetry: (_) => retried = 'm_0',
  );
  await tester.pumpAndSettle();

  expect(find.text('重试'), findsOneWidget);
  await tester.tap(find.text('重试'));
  expect(retried, 'm_0');
});
```

注意：`_pump` 当前签名没有 `onRetry` 参数，需扩展 `_pump`：把 `_pump` 的参数列表加 `void Function(String)? onRetry`，并在 `ChatMessageBubble(...)` 构造里传 `onRegenerate: onRetry == null ? null : (id) => onRetry!(id)`。已有调用不传 `onRetry` 即可（默认 null）。

另外已有测试 `推荐失败显示重试按钮且不显示重新生成操作`（line 205-222，kind=recommendation 的 error）断言 `find.text('重试推荐')`——这条保留，因为 recommendation kind 的 error 仍走 `重试推荐` FilledButton（见原 line 112-122 分支，不动）。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/chat/chat_message_bubble_test.dart`
Expected: 3 个新错误态测试 FAIL（当前 `_AssistantErrorView` 只显示 Text）。

- [ ] **Step 3: 重写 `_AssistantErrorView`**

把 `lib/features/chat/widgets/chat_message_bubble.dart` 末尾的 `_AssistantErrorView` 替换为：

```dart
class _AssistantErrorView extends StatefulWidget {
  const _AssistantErrorView({required this.message, this.onRetry});

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  State<_AssistantErrorView> createState() => _AssistantErrorViewState();
}

class _AssistantErrorViewState extends State<_AssistantErrorView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 20, color: cs.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '生成失败，可查看详情或重试',
                  style: TextStyle(color: cs.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? '收起' : '查看详情'),
              ),
              if (widget.onRetry != null)
                FilledButton.tonal(
                  onPressed: widget.onRetry,
                  child: const Text('重试'),
                ),
            ],
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 28),
              child: Text(
                widget.message.content,
                style: TextStyle(color: cs.error, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
```

注意：`_AssistantErrorView` 现在用于**普通对话**错误态（kind=conversation）。recommendation kind 的 error 仍走原 `重试推荐` 分支（原 line 112-122，不动）。确认 `build` 里 `_AssistantErrorView` 只在 `isError && message.kind != ChatMessageKind.recommendation` 时使用——但当前 Task P0.1 的 `build` 是 `if (isError) body = _AssistantErrorView(...)`，会覆盖 recommendation error。

修正 `build`：把 error 分支改成：

```dart
    final Widget body;
    final bool isRecommendationError =
        isError && message.kind == ChatMessageKind.recommendation;
    if (isError && !isRecommendationError) {
      body = _AssistantErrorView(
        message: message,
        onRetry: onRegenerate == null ? null : () => onRegenerate!(message.id),
      );
    } else if (isUser) {
      body = Text(message.content);
    } else {
      body = DefaultTextStyle(
        style: assistantStyle,
        child: GptMarkdown(message.content),
      );
    }
```

并让 `selectableContent`/`messageBody` 对 `isRecommendationError` 也按 AI（无气泡）处理——即 `isUser` 为 false，走 Padding 分支。recommendation error 的 `重试推荐` 按钮（原 line 112-122 的 `if (message.kind == ChatMessageKind.recommendation && ... error)`）仍在 Column 末尾单独渲染，不变。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/chat/chat_message_bubble_test.dart`
Expected: 全部 PASS（含旧 recommendation error 测试）。

- [ ] **Step 5: 运行相关 a11y 测试**

Run: `flutter test test/features/chat/`
Expected: 全 PASS。

- [ ] **Step 6: 上机肉眼验证**

Run: `flutter run`（或现有启动方式），进入导师对话页，发一条让 AI 失败的消息（断网或配错 key），观察：AI 错误态显示圆圈红感叹号 +「查看详情」+「重试」；点查看详情展开文案；正常 AI 回复全宽无气泡、行距收紧。如无法上机，明确说明。

- [ ] **Step 7: Commit**

```bash
git add lib/features/chat/widgets/chat_message_bubble.dart test/features/chat/chat_message_bubble_test.dart
git commit -m "feat(chat): AI 错误态改圆圈红感叹号+查看详情+重试"
```

---

# Phase P1：自建日期选择器

> 依赖：无。

## Task P1.1：日历日期 codec

**Files:**
- Create: `lib/core/calendar_date.dart`
- Test: `test/core/calendar_date_test.dart`

**Interfaces:**
- Produces: `CalendarDate`（静态方法 `normalize(DateTime)`、`toIsoDay(DateTime)`、`parseIsoDay(String)`、`clampDay(DateTime,DateTime,DateTime)`）

- [ ] **Step 1: 写失败测试**

Create `test/core/calendar_date_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/calendar_date.dart';

void main() {
  test('normalize 截掉时分秒到本地零点', () {
    final d = DateTime(2026, 5, 3, 13, 45, 9);
    expect(CalendarDate.normalize(d), DateTime(2026, 5, 3));
  });

  test('toIsoDay 输出 YYYY-MM-DD', () {
    expect(CalendarDate.toIsoDay(DateTime(2026, 5, 3)), '2026-05-03');
    expect(CalendarDate.toIsoDay(DateTime(2026, 12, 31)), '2026-12-31');
  });

  test('parseIsoDay 解析回本地零点 DateTime', () {
    expect(CalendarDate.parseIsoDay('2026-05-03'), DateTime(2026, 5, 3));
  });

  test('parseIsoDay 拒绝 date-time 混用', () {
    expect(() => CalendarDate.parseIsoDay('2026-05-03T10:00:00Z'),
        throwsA(isA<FormatException>()));
    expect(() => CalendarDate.parseIsoDay('not-a-date'),
        throwsA(isA<FormatException>()));
  });

  test('clampDay 闭区间夹取', () {
    final lo = DateTime(2026, 5, 1);
    final hi = DateTime(2026, 5, 10);
    expect(CalendarDate.clampDay(DateTime(2026, 4, 30), lo, hi), lo);
    expect(CalendarDate.clampDay(DateTime(2026, 5, 20), lo, hi), hi);
    expect(CalendarDate.clampDay(DateTime(2026, 5, 5), lo, hi), DateTime(2026, 5, 5));
  });

  test('toIsoDay/parseIsoDay 往返一致', () {
    final d = DateTime(2026, 6, 29);
    expect(CalendarDate.parseIsoDay(CalendarDate.toIsoDay(d)), d);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/core/calendar_date_test.dart`
Expected: FAIL（`CalendarDate` 未定义 / 找不到库）。

- [ ] **Step 3: 实现 codec**

Create `lib/core/calendar_date.dart`:

```dart
/// 日历日期工具（spec §2.1）：无时区日历日期的规范化与 YYYY-MM-DD 编解码。
class CalendarDate {
  CalendarDate._();

  /// 规范化为本地零点 `DateTime(y, m, d)`。
  static DateTime normalize(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// 输出 `YYYY-MM-DD`。
  static String toIsoDay(DateTime value) {
    final d = normalize(value);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// 解析 `YYYY-MM-DD` 为本地零点 DateTime。拒绝带时间或非法格式。
  static DateTime parseIsoDay(String value) {
    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!regex.hasMatch(value)) {
      throw const FormatException('expected YYYY-MM-DD calendar date');
    }
    return DateTime.parse(value);
  }

  /// 闭区间夹取。
  static DateTime clampDay(DateTime v, DateTime lo, DateTime hi) {
    if (v.isBefore(lo)) return lo;
    if (v.isAfter(hi)) return hi;
    return v;
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/core/calendar_date_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/core/calendar_date.dart test/core/calendar_date_test.dart
git commit -m "feat(core): 日历日期 codec normalize/YYYY-MM-DD"
```

---

## Task P1.2：PreparationDatePicker 三模式组件

**Files:**
- Create: `lib/features/preparation/widgets/preparation_date_picker.dart`
- Test: `test/features/preparation/widgets/preparation_date_picker_test.dart`

**Interfaces:**
- Produces: `PreparationDatePickerMode { single, range, multiAnchor }`、`PreparationDatePicker`（StatefulWidget，`showPreparationDatePicker` 异步弹窗返回 `PreparationDateSelection`）
- Produces: `PreparationDateSelection`（含 `DateTime? single`、`DateTime? rangeStart`、`DateTime? rangeEnd`、`DateTime? deadline`、`DateTime? defense`）

**设计：** 自建一个 BottomSheet 日历，月历网格选日。single 选 1 天；range 选起止 2 天（首点=起，再点=止，止>=起，否则互换）；multiAnchor 选 DDL + 可选答辩（DDL 必填、答辩可空且 >DDL）。组件内即时校验顺序，确认按钮在非法时禁用。返回值经 `CalendarDate.normalize`。

- [ ] **Step 1: 写失败测试**

Create `test/features/preparation/widgets/preparation_date_picker_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/preparation/widgets/preparation_date_picker.dart';

Future<void> _openPicker(
  WidgetTester tester,
  PreparationDatePickerMode mode, {
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showPreparationDatePicker(
              context: context,
              mode: mode,
              firstDate: firstDate,
              lastDate: lastDate,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('single 模式选一天返回 single', (tester) async {
    await _openPicker(tester, PreparationDatePickerMode.single,
        firstDate: DateTime(2026, 5, 1), lastDate: DateTime(2026, 7, 31));
    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
  });

  testWidgets('range 模式未选满禁用确认', (tester) async {
    await _openPicker(tester, PreparationDatePickerMode.range,
        firstDate: DateTime(2026, 5, 1), lastDate: DateTime(2026, 7, 31));
    await tester.tap(find.text('10'));
    await tester.pump();
    final confirm = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '确认'));
    expect((confirm.onPressed == null), isTrue);
  });

  testWidgets('multiAnchor 答辩可空且需晚于DDL', (tester) async {
    await _openPicker(tester, PreparationDatePickerMode.multiAnchor,
        firstDate: DateTime(2026, 5, 1), lastDate: DateTime(2026, 7, 31));
    await tester.tap(find.text('20'));
    await tester.pump();
    final confirm = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '确认'));
    expect((confirm.onPressed == null), isFalse);
  });

  testWidgets('返回值经规范化为本地零点', (tester) async {
    late PreparationDateSelection? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showPreparationDatePicker(
                  context: context,
                  mode: PreparationDatePickerMode.single,
                  firstDate: DateTime(2026, 5, 1),
                  lastDate: DateTime(2026, 7, 31),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(result?.single, DateTime(2026, 5, 15));
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/preparation/widgets/preparation_date_picker_test.dart`
Expected: FAIL（组件未定义）。

- [ ] **Step 3: 实现日期选择器**

Create `lib/features/preparation/widgets/preparation_date_picker.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/calendar_date.dart';
import '../../../core/theme/app_colors.dart';

enum PreparationDatePickerMode { single, range, multiAnchor }

class PreparationDateSelection {
  const PreparationDateSelection({
    this.single,
    this.rangeStart,
    this.rangeEnd,
    this.deadline,
    this.defense,
  });
  final DateTime? single;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final DateTime? deadline;
  final DateTime? defense;
}

Future<PreparationDateSelection?> showPreparationDatePicker({
  required BuildContext context,
  required PreparationDatePickerMode mode,
  required DateTime firstDate,
  required DateTime lastDate,
  PreparationDateSelection? initial,
}) {
  return showModalBottomSheet<PreparationDateSelection>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PreparationDatePickerSheet(
      mode: mode,
      firstDate: CalendarDate.normalize(firstDate),
      lastDate: CalendarDate.normalize(lastDate),
      initial: initial,
    ),
  );
}

class _PreparationDatePickerSheet extends StatefulWidget {
  const _PreparationDatePickerSheet({
    required this.mode,
    required this.firstDate,
    required this.lastDate,
    this.initial,
  });
  final PreparationDatePickerMode mode;
  final DateTime firstDate;
  final DateTime lastDate;
  final PreparationDateSelection? initial;

  @override
  State<_PreparationDatePickerSheet> createState() =>
      _PreparationDatePickerSheetState();
}

class _PreparationDatePickerSheetState
    extends State<_PreparationDatePickerSheet> {
  late DateTime _focusedMonth;
  DateTime? _single;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime? _deadline;
  DateTime? _defense;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final init = widget.initial;
    if (init != null) {
      _single = init.single;
      _rangeStart = init.rangeStart;
      _rangeEnd = init.rangeEnd;
      _deadline = init.deadline;
      _defense = init.defense;
    }
  }

  bool get _canConfirm {
    switch (widget.mode) {
      case PreparationDatePickerMode.single:
        return _single != null;
      case PreparationDatePickerMode.range:
        return _rangeStart != null && _rangeEnd != null;
      case PreparationDatePickerMode.multiAnchor:
        if (_deadline == null) return false;
        if (_defense != null && !_defense!.isAfter(_deadline!)) return false;
        return true;
    }
  }

  void _selectDay(DateTime day) {
    Haptics.selection();
    setState(() {
      switch (widget.mode) {
        case PreparationDatePickerMode.single:
          _single = day;
          break;
        case PreparationDatePickerMode.range:
          if (_rangeStart == null || (_rangeStart != null && _rangeEnd != null)) {
            _rangeStart = day;
            _rangeEnd = null;
          } else {
            if (!day.isBefore(_rangeStart!)) {
              _rangeEnd = day;
            } else {
              _rangeEnd = _rangeStart;
              _rangeStart = day;
            }
          }
          break;
        case PreparationDatePickerMode.multiAnchor:
          // 点两次：先填 deadline，再填 defense；点已选的 defense 可清空。
          if (_deadline == null || (_defense != null && day == _defense)) {
            if (_defense != null && day == _defense) {
              _defense = null;
            } else {
              _deadline = day;
            }
          } else if (_defense == null && day.isAfter(_deadline!)) {
            _defense = day;
          } else {
            // 重选：当作重新开始选 DDL。
            _deadline = day;
            _defense = null;
          }
          break;
      }
    });
  }

  PreparationDateSelection _result() {
    switch (widget.mode) {
      case PreparationDatePickerMode.single:
        return PreparationDateSelection(single: _single);
      case PreparationDatePickerMode.range:
        return PreparationDateSelection(
            rangeStart: _rangeStart, rangeEnd: _rangeEnd);
      case PreparationDatePickerMode.multiAnchor:
        return PreparationDateSelection(deadline: _deadline, defense: _defense);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 8),
            _monthNav(),
            const SizedBox(height: 4),
            _weekHeader(),
            _grid(),
            const SizedBox(height: 12),
            _statusText(),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _canConfirm ? () => Navigator.pop(context, _result()) : null,
              child: const Align(
                alignment: Alignment.center,
                child: Text('确认'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final title = switch (widget.mode) {
      PreparationDatePickerMode.single => '选择日期',
      PreparationDatePickerMode.range => '选择比赛起止日期',
      PreparationDatePickerMode.multiAnchor => '选择提交 DDL 与答辩',
    };
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }

  Widget _monthNav() {
    final cs = Theme.of(context).colorScheme;
    final label =
        '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}';
    final canPrev = !_focusedMonth.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month));
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    final canNext = !next.isAfter(widget.lastDate);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: canPrev
              ? () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1))
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
        IconButton(
          onPressed: canNext
              ? () => setState(() => _focusedMonth = next)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _weekHeader() {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: labels
          .map((l) => Expanded(
                child: Center(
                  child: Text(l,
                      style: const TextStyle(
                          color: AppColors.inkFaint, fontSize: 12)),
                ),
              ))
          .toList(),
    );
  }

  Widget _grid() {
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    // 周一为首：weekday 1=Monday..7=Sunday
    final lead = firstOfMonth.weekday - 1;
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_focusedMonth.year, _focusedMonth.month, d);
      final inRange = !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate);
      cells.add(_dayCell(day, inRange));
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: cells,
    );
  }

  Widget _dayCell(DateTime day, bool inRange) {
    final cs = Theme.of(context).colorScheme;
    final selected = _isSelected(day);
    final inSpan = _inSelectedSpan(day);
    Color? bg;
    Color fg = cs.onSurface;
    if (selected) {
      bg = AppColors.indigo;
      fg = Colors.white;
    } else if (inSpan) {
      bg = AppColors.indigoSoft;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: inRange ? () => _selectDay(day) : null,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        child: Text('${day.day}', style: TextStyle(color: fg)),
      ),
    );
  }

  bool _isSelected(DateTime day) {
    switch (widget.mode) {
      case PreparationDatePickerMode.single:
        return day == _single;
      case PreparationDatePickerMode.range:
        return day == _rangeStart || day == _rangeEnd;
      case PreparationDatePickerMode.multiAnchor:
        return day == _deadline || day == _defense;
    }
  }

  bool _inSelectedSpan(DateTime day) {
    if (widget.mode != PreparationDatePickerMode.range) return false;
    if (_rangeStart == null || _rangeEnd == null) return false;
    return !day.isBefore(_rangeStart!) && !day.isAfter(_rangeEnd!) &&
        day != _rangeStart && day != _rangeEnd;
  }

  Widget _statusText() {
    String text;
    switch (widget.mode) {
      case PreparationDatePickerMode.single:
        text = _single == null ? '请选择日期' : '已选 ${CalendarDate.toIsoDay(_single!)}';
        break;
      case PreparationDatePickerMode.range:
        if (_rangeStart == null) {
          text = '请选择比赛开始日';
        } else if (_rangeEnd == null) {
          text = '开始 ${CalendarDate.toIsoDay(_rangeStart!)}，请选结束日';
        } else {
          text = '比赛 ${CalendarDate.toIsoDay(_rangeStart!)} – ${CalendarDate.toIsoDay(_rangeEnd!)}';
        }
        break;
      case PreparationDatePickerMode.multiAnchor:
        final dl = _deadline == null ? '未选' : CalendarDate.toIsoDay(_deadline!);
        final df = _defense == null ? '无' : CalendarDate.toIsoDay(_defense!);
        text = '提交 DDL：$dl · 答辩：$df';
        break;
    }
    return Text(text, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13));
  }
}
```

注意：`Haptics` 来自 `lib/core/haptics/haptics.dart`（详情页已用），顶部加 `import '../../../core/haptics/haptics.dart';`。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/preparation/widgets/preparation_date_picker_test.dart`
Expected: PASS。若 `single 模式选一天返回 single`（第一条 test）未断言结果，可保留为冒烟测试；关键是后三条断言通过。

- [ ] **Step 5: analyze + a11y**

Run: `flutter analyze lib/features/preparation/widgets/preparation_date_picker.dart lib/core/calendar_date.dart`
Expected: No issues。

- [ ] **Step 6: Commit**

```bash
git add lib/features/preparation/widgets/preparation_date_picker.dart test/features/preparation/widgets/preparation_date_picker_test.dart lib/core/calendar_date.dart
git commit -m "feat(preparation): 自建三模式日期选择器"
```

---

# Phase P2：双段时间模型

> 依赖：P1。

## Task P2.1：PreparationPlan 实体扩展 + legacy 默认

**Files:**
- Modify: `lib/domain/entities/preparation_plan.dart:21-22, 258-354`
- Test: `test/domain/entities/preparation_plan_test.dart`

**Interfaces:**
- Produces: `enum CompetitionTimelineType { eventWindow, submission }`（放本文件顶部）；`PreparationPlan` 新增 `timelineType`（默认 `submission`）、`eventEndDate`、`defenseDate`、`revision`（默认 0）；`fromJson` 对缺失字段给 legacy 默认。

- [ ] **Step 1: 写失败测试**

追加到 `test/domain/entities/preparation_plan_test.dart`（若不存在则新建，参考已有同类测试结构）:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

void main() {
  group('PreparationPlan 双段时间模型', () {
    test('toJson/fromJson 往返保留 timelineType/eventEndDate/defenseDate/revision', () {
      final plan = PreparationPlan(
        id: 'pp_1',
        competition: _comp(),
        targetDate: DateTime(2026, 6, 1),
        timelineType: CompetitionTimelineType.eventWindow,
        eventEndDate: DateTime(2026, 6, 3),
        defenseDate: null,
        weeklyCommitment: WeeklyCommitment.hours6to10,
        experienceLevel: ExperienceLevel.intermediate,
        status: PreparationPlanStatus.active,
        phases: const [],
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
        revision: 0,
      );
      final decoded = PreparationPlan.fromJson(plan.toJson());
      expect(decoded.timelineType, CompetitionTimelineType.eventWindow);
      expect(decoded.eventEndDate, DateTime(2026, 6, 3));
      expect(decoded.defenseDate, isNull);
      expect(decoded.revision, 0);
    });

    test('旧 v1 JSON（缺新字段）默认 submission + revision 0', () {
      final legacy = <String, dynamic>{
        'id': 'pp_old',
        'competition': _comp().toJson(),
        'target_date': '2026-06-01T00:00:00.000',
        'weekly_commitment': 'hours6to10',
        'experience_level': 'intermediate',
        'status': 'active',
        'phases': <dynamic>[],
        'created_at': '2026-05-01T00:00:00.000Z',
        'updated_at': '2026-05-01T00:00:00.000Z',
        'tight_schedule': false,
        'overload': false,
      };
      final plan = PreparationPlan.fromJson(legacy);
      expect(plan.timelineType, CompetitionTimelineType.submission);
      expect(plan.eventEndDate, isNull);
      expect(plan.defenseDate, isNull);
      expect(plan.revision, 0);
    });
  });
}

CompetitionSnapshot _comp() => CompetitionSnapshot(
      id: 'c1',
      name: '测试赛',
      category: '计算机类',
      rulesSummary: CompetitionRulesSummary(
        signupTime: '2026-01',
        contestTime: '2026-06',
        teamSize: '3',
        format: '现场',
        organizer: '某',
      ),
    );
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/domain/entities/preparation_plan_test.dart`
Expected: FAIL（新字段未定义）。

- [ ] **Step 3: 扩展实体**

修改 `lib/domain/entities/preparation_plan.dart`：

在 `enum ExperienceLevel`（line 22）之后加：

```dart
/// 赛事时间模型：窗口型（比赛集中在几天）/ 提交型（作品提交到 DDL）。
enum CompetitionTimelineType { eventWindow, submission }
```

修改 `PreparationPlan` 构造（line 258-272）：在 `required this.targetDate,` 之后加 `this.timelineType = CompetitionTimelineType.submission,`、`this.eventEndDate,`、`this.defenseDate,`、`this.revision = 0,`。对应 final 字段（line 274-285 后）加：

```dart
  final CompetitionTimelineType timelineType;
  final DateTime? eventEndDate;
  final DateTime? defenseDate;
  final int revision;
```

`copyWith`（line 287-314）加参数 `CompetitionTimelineType? timelineType, DateTime? eventEndDate, DateTime? defenseDate, int? revision,` 并在返回里传递。

`toJson`（line 316-330）加：
```dart
        'timeline_type': timelineType.name,
        if (eventEndDate != null)
          'event_end_date': CalendarDate.toIsoDay(eventEndDate!),
        if (defenseDate != null)
          'defense_date': CalendarDate.toIsoDay(defenseDate!),
        'revision': revision,
```
（需 `import '../../core/calendar_date.dart';`）

`fromJson`（line 332-353）加：
```dart
        timelineType: CompetitionTimelineType.values.byName(
          (json['timeline_type'] as String?) ?? 'submission',
        ),
        eventEndDate: json['event_end_date'] == null
            ? null
            : CalendarDate.parseIsoDay(json['event_end_date'] as String),
        defenseDate: json['defense_date'] == null
            ? null
            : CalendarDate.parseIsoDay(json['defense_date'] as String),
        revision: (json['revision'] as int?) ?? 0,
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/domain/entities/preparation_plan_test.dart`
Expected: PASS。

- [ ] **Step 5: 检查既有 preparation 测试未破**

Run: `flutter test test/domain/entities/ test/data/local/local_preparation_plan_repository_test.dart test/domain/services/`
Expected: PASS（旧测试构造 plan 时不传新字段，走默认值，应仍通过；若旧测试用位置参数构造会失败，改为具名参数）。

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/preparation_plan.dart test/domain/entities/preparation_plan_test.dart
git commit -m "feat(preparation): PreparationPlan 双段时间字段+revision+legacy默认"
```

---

## Task P2.2：LocalPreparationPlanRepository v2 迁移

**Files:**
- Modify: `lib/data/local/local_preparation_plan_repository.dart:11, 47-55, 76-104`
- Modify: `lib/core/error/app_exception.dart`（加 `ConflictException`）
- Test: `test/data/local/local_preparation_plan_repository_test.dart`

**Interfaces:**
- Produces: `LocalPreparationPlanRepository.storageKey = 'competition_preparation_plans.v2'`；v2 缺失时一次性从 v1 迁移（submission/null/null/revision=0，保留阶段任务，不重排）；v1 保留不删。

- [ ] **Step 1: 写失败测试**

追加到 `test/data/local/local_preparation_plan_repository_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/storage/shared_preferences_local_store.dart';
import 'package:scho_navi/data/local/local_preparation_plan_repository.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

SharedPreferencesLocalStore _storeWith(Map<String, Object> prefs) {
  SharedPreferences.setMockInitialValues(prefs);
  return SharedPreferencesLocalStore(await SharedPreferences.getInstance());
}

void main() {
  group('v2 迁移', () {
    test('v1 存在且 v2 缺失时迁移为 submission + revision 0', () async {
      final store = await _storeWith({
        'competition_preparation_plans.v1': [_legacyPlanJson()],
      });
      final repo = LocalPreparationPlanRepository(store, now: () => DateTime(2026, 6, 1));
      final plans = repo.list();
      expect(plans, hasLength(1));
      expect(plans.first.timelineType, CompetitionTimelineType.submission);
      expect(plans.first.revision, 0);
      // v2 已写入
      expect(store.getJsonList('competition_preparation_plans.v2'), isNotNull);
      // v1 保留
      expect(store.getJsonList('competition_preparation_plans.v1'), isNotNull);
    });

    test('v2 已存在时不重新迁移', () async {
      final store = await _storeWith({
        'competition_preparation_plans.v1': [_legacyPlanJson()],
        'competition_preparation_plans.v2': [_v2PlanJson()],
      });
      final repo = LocalPreparationPlanRepository(store, now: () => DateTime(2026, 6, 1));
      final plans = repo.list();
      expect(plans.first.id, 'pp_v2');
    });

    test('v1 单条损坏降级，保留其他合法', () async {
      final store = await _storeWith({
        'competition_preparation_plans.v1': [
          {'broken': 'not a plan'},
          _legacyPlanJson(),
        ],
      });
      final repo = LocalPreparationPlanRepository(store, now: () => DateTime(2026, 6, 1));
      final plans = repo.list();
      expect(plans, hasLength(1));
      expect(plans.first.id, 'pp_legacy');
    });
  });
}

Map<String, dynamic> _legacyPlanJson() => {
  'id': 'pp_legacy',
  'competition': {
    'id': 'c1', 'name': '赛', 'category': '计算机类',
    'rules_summary': {'signup_time':'1','contest_time':'2','team_size':'3','format':'现场','organizer':'o'},
  },
  'target_date': '2026-06-01T00:00:00.000',
  'weekly_commitment': 'hours6to10',
  'experience_level': 'intermediate',
  'status': 'active',
  'phases': <dynamic>[],
  'created_at': '2026-05-01T00:00:00.000Z',
  'updated_at': '2026-05-01T00:00:00.000Z',
  'tight_schedule': false,
  'overload': false,
};

Map<String, dynamic> _v2PlanJson() => {
  'id': 'pp_v2',
  'competition': {
    'id': 'c1', 'name': '赛', 'category': '计算机类',
    'rules_summary': {'signup_time':'1','contest_time':'2','team_size':'3','format':'现场','organizer':'o'},
  },
  'target_date': '2026-06-01',
  'weekly_commitment': 'hours6to10',
  'experience_level': 'intermediate',
  'status': 'active',
  'phases': <dynamic>[],
  'created_at': '2026-05-01T00:00:00.000Z',
  'updated_at': '2026-05-01T00:00:00.000Z',
  'tight_schedule': false,
  'overload': false,
  'timeline_type': 'submission',
  'revision': 2,
};
```

注意：`_storeWith` 里 `await` 需改成 async（`Future<SharedPreferencesLocalStore> _storeWith(...)`）并 `return SharedPreferencesLocalStore(await SharedPreferences.getInstance());`。修正该 helper。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/local/local_preparation_plan_repository_test.dart`
Expected: FAIL（storageKey 仍是 v1，无迁移）。

- [ ] **Step 3: 加 ConflictException**

在 `lib/core/error/app_exception.dart` 末尾加：

```dart
class ConflictException extends AppException {
  const ConflictException() : super('数据已变化，请刷新后重试');
}
```

- [ ] **Step 4: 实现 v2 迁移 + compare-and-set 写队列**

改 `lib/data/local/local_preparation_plan_repository.dart`。把 `storageKey` 改为 `'competition_preparation_plans.v2'`，并加 v1 key 与写队列：

```dart
class LocalPreparationPlanRepository implements PreparationPlanRepository {
  LocalPreparationPlanRepository(this._store, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const String storageKey = 'competition_preparation_plans.v2';
  static const String _legacyKey = 'competition_preparation_plans.v1';

  final LocalStore _store;
  final DateTime Function() _now;
  final StreamController<List<PreparationPlan>> _controller =
      StreamController<List<PreparationPlan>>.broadcast();
  Future<void> _writeGuard = Future<void>.value();

  @override
  List<PreparationPlan> list() => _readAll();

  @override
  PreparationPlan? findById(String id) {
    for (final plan in list()) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  @override
  PreparationPlan? activeForCompetition(String competitionId) {
    for (final plan in list()) {
      if (plan.status == PreparationPlanStatus.active &&
          plan.competition.id == competitionId) {
        return plan;
      }
    }
    return null;
  }

  @override
  Stream<List<PreparationPlan>> watch() async* {
    yield list();
    yield* _controller.stream;
  }

  @override
  Future<PreparationPlan> save(PreparationPlan plan) => _enqueue(() async {
        final existing = list().where((p) => p.id == plan.id).toList();
        final isNew = existing.isEmpty;
        if (isNew && plan.revision != 0) {
          throw const ConflictException();
        }
        if (!isNew && existing.first.revision != plan.revision) {
          throw const ConflictException();
        }
        final updated = plan.copyWith(
          updatedAt: _now(),
          revision: plan.revision + 1,
        );
        final plans = [
          updated,
          ...list().where((current) => current.id != plan.id),
        ];
        await _writeAll(plans);
        return updated;
      });

  @override
  Future<void> archive(String id) async {
    final plan = findById(id);
    if (plan == null) return;
    await save(plan.copyWith(status: PreparationPlanStatus.archived));
  }

  @override
  Future<void> delete(String id) async {
    await _enqueue(() async {
      final plans = list().where((plan) => plan.id != id).toList();
      await _writeAll(plans);
    });
  }

  void dispose() => _controller.close();

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final completer = _writeGuard.then((_) => task());
    _writeGuard = completer.then((_) {}, onError: (_) {});
    return completer;
  }

  List<PreparationPlan> _readAll() {
    final migrated = _migrateIfNeeded();
    final raw = migrated ?? _store.getJsonList(storageKey);
    if (raw == null) return const [];
    final plans = <PreparationPlan>[];
    for (final entry in raw) {
      final plan = _parsePlan(entry);
      if (plan != null) plans.add(plan);
    }
    return plans;
  }

  /// 首次读取时若 v2 缺失则从 v1 迁移；返回迁移后应使用的 list（可能 null=未迁移）。
  List<dynamic>? _migrateIfNeeded() {
    final v2 = _store.getJsonList(storageKey);
    if (v2 != null) return v2;
    final v1 = _store.getJsonList(_legacyKey);
    if (v1 == null) return null;
    final migrated = <Map<String, dynamic>>[];
    for (final entry in v1) {
      final plan = _parsePlan(entry);
      if (plan != null) migrated.add(plan.toJson());
    }
    // 同步写入 v2（_store 为 SharedPreferences，setJsonList 同步可行）。
    _store.setJsonList(storageKey, migrated);
    return migrated;
  }

  PreparationPlan? _parsePlan(Object? entry) {
    if (entry is! Map) return null;
    try {
      final json = Map<String, dynamic>.from(entry);
      return PreparationPlan.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeAll(List<PreparationPlan> plans) async {
    await _store.setJsonList(
      storageKey,
      plans.map((plan) => plan.toJson()).toList(growable: false),
    );
    _controller.add(List<PreparationPlan>.unmodifiable(plans));
  }
}
```

注意：`_migrateIfNeeded` 调用 `_store.setJsonList`——确认 `LocalStore.setJsonList` 是同步可调用（SharedPreferences 实际 async，但项目 `SharedPreferencesLocalStore` 一般 await；若 `setJsonList` 是 `Future<void>`，则 `_migrateIfNeeded` 不能在同步 `_readAll` 里调）。**需先确认 `LocalStore` 接口。**

- [ ] **Step 5: 确认 LocalStore 接口**

Run: `flutter analyze lib/data/local/local_preparation_plan_repository.dart`
若报 `_store.setJsonList` 在同步上下文返回 Future 的问题，则把迁移改为「懒异步迁移」：`list()` 仍是同步读 v2 或**未迁移的 v1 直接解码**（不写 v2），`save`/`delete` 第一次写入时再把全量写 v2。这样避免同步写。

**采用懒迁移方案**（更稳妥）：`_migrateIfNeeded` 只决定从哪个 key 读，不写：

```dart
  List<PreparationPlan> _readAll() {
    final raw = _store.getJsonList(storageKey) ?? _store.getJsonList(_legacyKey);
    if (raw == null) return const [];
    final plans = <PreparationPlan>[];
    for (final entry in raw) {
      final plan = _parsePlan(entry);
      if (plan != null) plans.add(plan);
    }
    return plans;
  }
```

并在 `save`/`delete` 的 `_writeAll` 后额外清理：**v1 不删**（保留回滚），但首次写 v2 后旧 v1 读路径因 v2 已存在而短路。测试「v1 保留」断言 v1 仍可读即可。

对应调整测试 Step 1 的断言：迁移发生在**首次 save 之后** v2 才被写入；`list()` 读到的是 v1 解码后的 plan（已带 submission 默认）。把第一个测试改为：先 `repo.list()` 得到迁移读（v1 解码），断言 `timelineType==submission && revision==0`；再 `await repo.save(plan)`，然后断言 v2 非空、v1 仍在。

- [ ] **Step 6: 运行测试确认通过**

Run: `flutter test test/data/local/local_preparation_plan_repository_test.dart`
Expected: PASS。

- [ ] **Step 7: 既有仓库测试回归**

Run: `flutter test test/data/local/local_preparation_plan_repository_test.dart test/features/preparation/`
Expected: PASS（详情页测试若 `save` 后断言返回值的 `revision`，需适配 +1）。

- [ ] **Step 8: Commit**

```bash
git add lib/data/local/local_preparation_plan_repository.dart lib/core/error/app_exception.dart test/data/local/local_preparation_plan_repository_test.dart
git commit -m "feat(preparation): 计划仓库 v2 迁移+compare-and-set 写队列"
```

---

## Task P2.3：competition_timeline_defaults + override JSON 迁移

**Files:**
- Create: `lib/data/fixtures/competition_timeline_defaults.dart`
- Modify: `assets/preparation_templates/competition_overrides.json`
- Test: `test/data/fixtures/preparation_templates_json_test.dart`

**Interfaces:**
- Produces: `CompetitionTimelineDefaults.defaultFor(String competitionId)` 返回 `CompetitionTimelineType?`（未知返回 null）

- [ ] **Step 1: 写失败测试**

追加到 `test/data/fixtures/preparation_templates_json_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/fixtures/competition_timeline_defaults.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

void main() {
  group('competition_timeline_defaults', () {
    test('ICPC 与蓝桥杯默认窗口型', () {
      expect(CompetitionTimelineDefaults.defaultFor('comp_icpc'),
          CompetitionTimelineType.eventWindow);
      expect(CompetitionTimelineDefaults.defaultFor('comp_lanqiao'),
          CompetitionTimelineType.eventWindow);
    });

    test('未知赛事返回 null', () {
      expect(CompetitionTimelineDefaults.defaultFor('comp_unknown'), isNull);
    });
  });
}
```

并在已有 JSON 测试里加断言（ICPC override 的 phase key 都属窗口型骨架）：

```dart
    test('ICPC override phase keys 全部属窗口型骨架', () {
      const windowKeys = {
        'team_formation', 'rules_review', 'skill_training', 'mock_event', 'final_check'
      };
      for (final phase in icpcOverrides['comp_icpc']['phases'] as List) {
        expect(windowKeys, contains(phase['key']));
      }
    });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/fixtures/preparation_templates_json_test.dart`
Expected: FAIL。

- [ ] **Step 3: 创建 defaults 配置**

Create `lib/data/fixtures/competition_timeline_defaults.dart`:

```dart
import '../../domain/entities/preparation_plan.dart';

/// 已知赛事的默认时间模型（spec §2.3）。按 competition ID 决定，不靠名称猜。
class CompetitionTimelineDefaults {
  const CompetitionTimelineDefaults._();

  static const Map<String, CompetitionTimelineType> _byId = {
    'comp_icpc': CompetitionTimelineType.eventWindow,
    'comp_lanqiao': CompetitionTimelineType.eventWindow,
  };

  static CompetitionTimelineType? defaultFor(String competitionId) =>
      _byId[competitionId];
}
```

- [ ] **Step 4: 迁移 override JSON**

修改 `assets/preparation_templates/competition_overrides.json`：把 `comp_icpc`、`comp_lanqiao` 的 phase key 从 `proposal_writing` 改为窗口型骨架 key（`skill_training`/`mock_event`/`final_check` 等），保留 templateKey 不变。按 spec §2.3 迁移表：

- `comp_icpc` 的 `icpc_trio`：phase `team_formation` 不变
- `comp_icpc` 的 `icpc_train`：phase `proposal_writing` → `skill_training`
- `comp_icpc` 的 `icpc_mock`：phase `proposal_writing` → `mock_event`
- `comp_lanqiao` 的 `lanqiao_past`：phase `proposal_writing` → `skill_training`
- `comp_lanqiao` 的 `lanqiao_template`：phase `proposal_writing` → `final_check`

先 Read 现有 JSON 确认当前结构，再按上表逐条 Edit。

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/data/fixtures/preparation_templates_json_test.dart`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/data/fixtures/competition_timeline_defaults.dart assets/preparation_templates/competition_overrides.json test/data/fixtures/preparation_templates_json_test.dart
git commit -m "feat(preparation): ICPC/蓝桥杯默认窗口型 + override 迁移"
```

---

## Task P2.4：PreparationTemplateProvider 按 timelineType 加载

**Files:**
- Modify: `lib/domain/repositories/preparation_template_provider.dart`
- Modify: `lib/data/fixtures/preparation_templates.dart`（加窗口骨架）
- Modify: `lib/data/local/local_preparation_template_provider.dart`
- Test: `test/data/local/local_preparation_template_provider_test.dart`

**Interfaces:**
- Produces: `PreparationTemplateProvider.load({required CompetitionTimelineType timelineType, required bool includeDefense, required String category, required String competitionId})`
- Produces: `defaultPreparationTemplate(CompetitionTimelineType type)`、`defaultWindowTemplate()`

- [ ] **Step 1: 写失败测试**

追加到 `test/data/local/local_preparation_template_provider_test.dart`：

```dart
test('窗口型只加载窗口骨架阶段', () async {
  final provider = LocalPreparationTemplateProvider(bundle: _FakeBundle());
  final t = await provider.load(
    timelineType: CompetitionTimelineType.eventWindow,
    includeDefense: false,
    category: '计算机类',
    competitionId: 'comp_icpc',
  );
  final keys = t.phases.map((p) => p.key).toSet();
  expect(keys, containsAll(['team_formation', 'rules_review', 'skill_training', 'mock_event', 'final_check']));
  expect(keys, isNot(contains('proposal_writing')));
  expect(keys, isNot(contains('defense_prep')));
});

test('提交型无答辩不生成 defense_prep', () async {
  final provider = LocalPreparationTemplateProvider(bundle: _FakeBundle());
  final t = await provider.load(
    timelineType: CompetitionTimelineType.submission,
    includeDefense: false,
    category: '计算机类',
    competitionId: 'comp_x',
  );
  expect(t.phases.map((p) => p.key), isNot(contains('defense_prep')));
});

test('提交型有答辩追加 defense_prep', () async {
  final provider = LocalPreparationTemplateProvider(bundle: _FakeBundle());
  final t = await provider.load(
    timelineType: CompetitionTimelineType.submission,
    includeDefense: true,
    category: '计算机类',
    competitionId: 'comp_x',
  );
  expect(t.phases.map((p) => p.key), contains('defense_prep'));
});
```

`_FakeBundle`：复用已有测试里的 fake AssetBundle（若无则建一个返回空 JSON 的）。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/local/local_preparation_template_provider_test.dart`
Expected: FAIL。

- [ ] **Step 3: 改接口 + 加窗口骨架**

改 `lib/domain/repositories/preparation_template_provider.dart`：`load` 签名改为具名参数（见上）。若该文件用 abstract interface，照原样改。

改 `lib/data/fixtures/preparation_templates.dart`：把现有 `defaultPreparationTemplate()` 改为 `defaultPreparationTemplate(CompetitionTimelineType type)`，并加：

```dart
import '../../domain/entities/preparation_plan.dart' show CompetitionTimelineType;

PreparationTemplate defaultPreparationTemplate(CompetitionTimelineType type) =>
    type == CompetitionTimelineType.eventWindow
        ? _windowTemplate()
        : _submissionTemplate(includeDefense: false);

PreparationTemplate _windowTemplate() => const PreparationTemplate(phases: [
  PreparationTemplatePhase(key: 'team_formation', title: '组队', weight: 0.15,
    requiredTasks: [PreparationTemplateTask(templateKey: 'team_form', title: '组建队伍并明确分工', estimatedHours: 3)],
    optionalTasks: const []),
  PreparationTemplatePhase(key: 'rules_review', title: '规则研读', weight: 0.15,
    requiredTasks: [PreparationTemplateTask(templateKey: 'rules_read', title: '研读竞赛规则与评分', estimatedHours: 2)],
    optionalTasks: const []),
  PreparationTemplatePhase(key: 'skill_training', title: '专项训练', weight: 0.35,
    requiredTasks: [PreparationTemplateTask(templateKey: 'train_core', title: '核心技能专项训练', estimatedHours: 12)],
    optionalTasks: [PreparationTemplateTask(templateKey: 'train_extra', title: '薄弱点补强', estimatedHours: 6)]),
  PreparationTemplatePhase(key: 'mock_event', title: '模拟比赛', weight: 0.20,
    requiredTasks: [PreparationTemplateTask(templateKey: 'mock_run', title: '完整模拟一场', estimatedHours: 5)],
    optionalTasks: const []),
  PreparationTemplatePhase(key: 'final_check', title: '赛前检查', weight: 0.15,
    requiredTasks: [PreparationTemplateTask(templateKey: 'env_check', title: '环境与装备检查', estimatedHours: 1)],
    optionalTasks: const []),
]);

PreparationTemplate _submissionTemplate({required bool includeDefense}) {
  final phases = <PreparationTemplatePhase>[
    const PreparationTemplatePhase(key: 'team_formation', title: '组队', weight: 0.15,
      requiredTasks: [PreparationTemplateTask(templateKey: 'team_form', title: '组建队伍并明确分工', estimatedHours: 3)],
      optionalTasks: []),
    const PreparationTemplatePhase(key: 'topic_selection', title: '选题', weight: 0.20,
      requiredTasks: [PreparationTemplateTask(templateKey: 'topic_decide', title: '确定选题并立项', estimatedHours: 2)],
      optionalTasks: []),
    const PreparationTemplatePhase(key: 'proposal_writing', title: '方案撰写', weight: 0.35,
      requiredTasks: [PreparationTemplateTask(templateKey: 'draft', title: '完成初稿', estimatedHours: 12)],
      optionalTasks: []),
    const PreparationTemplatePhase(key: 'submission_polish', title: '打磨提交', weight: 0.15,
      requiredTasks: [PreparationTemplateTask(templateKey: 'submit', title: '按官网要求提交', estimatedHours: 1)],
      optionalTasks: []),
  ];
  if (includeDefense) {
    phases.add(const PreparationTemplatePhase(key: 'defense_prep', title: '答辩准备', weight: 0.15,
      requiredTasks: [PreparationTemplateTask(templateKey: 'slides', title: '制作答辩 PPT', estimatedHours: 4)],
      optionalTasks: []));
  }
  return PreparationTemplate(phases: phases);
}
```

- [ ] **Step 4: 改 LocalPreparationTemplateProvider**

改 `lib/data/local/local_preparation_template_provider.dart` 的 `load`：

```dart
  @override
  Future<PreparationTemplate> load({
    required CompetitionTimelineType timelineType,
    required bool includeDefense,
    required String category,
    required String competitionId,
  }) async {
    final base = defaultPreparationTemplate(timelineType);
    // ...沿用原 byKey/mergedRequired/mergedOptional 构建逻辑...
    // category / competitionId 叠加逻辑不变（applyEntry）。
    // includeDefense 已由 defaultPreparationTemplate 处理，这里不再追加。
    return PreparationTemplate(...);
  }
```

注意原 `load(String? category, String? competitionId)` 调用点（generator、测试）需同步改。

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/data/local/local_preparation_template_provider_test.dart`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/domain/repositories/preparation_template_provider.dart lib/data/fixtures/preparation_templates.dart lib/data/local/local_preparation_template_provider.dart test/data/local/local_preparation_template_provider_test.dart
git commit -m "feat(preparation): 模板按 timelineType 加载+窗口骨架"
```

---

## Task P2.5：分段排期 + generator 适配

**Files:**
- Modify: `lib/domain/services/preparation_scheduler.dart`
- Modify: `lib/domain/services/preparation_plan_generator.dart`
- Modify: `lib/data/dto/preparation_plan_dtos.dart`（generate 入参扩展）
- Modify: `lib/data/ai/ai_preparation_personalizer.dart`（prompt 扩展）
- Test: `test/domain/services/preparation_scheduler_test.dart`
- Test: `test/domain/services/preparation_plan_generator_test.dart`

**Interfaces:**
- Produces: `PreparationScheduler.scheduleSegment({required List<PreparationTemplatePhase> phases, required DateTime today, required DateTime segmentEnd})`（对单个闭区间排期）
- Produces: generator `generate` 新增 `timelineType`/`eventEndDate`/`defenseDate`/`experienceLevel`（已有）/`calendarToday`

- [ ] **Step 1: 写失败测试（scheduler 分段）**

追加到 `test/domain/services/preparation_scheduler_test.dart`：

```dart
test('scheduleSegment 在闭区间内按权重分配', () {
  final segs = PreparationScheduler.scheduleSegment(
    phases: [_p('a', 0.5), _p('b', 0.5)],
    today: DateTime(2026, 5, 1),
    segmentEnd: DateTime(2026, 5, 10),
  );
  expect(segs.first.startDate, DateTime(2026, 5, 1));
  expect(segs.last.endDate, DateTime(2026, 5, 10));
  expect(segs.length, 2);
});

test('窗口型任务不越过 targetDate', () {
  // generator 层断言，见 generator 测试
});
```

`_p` 是已有 helper 或新建：`PreparationTemplatePhase(key:'a', title:'a', weight:0.5, requiredTasks:const[], optionalTasks:const[])`。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/domain/services/preparation_scheduler_test.dart`
Expected: FAIL。

- [ ] **Step 3: 加 scheduleSegment**

在 `lib/domain/services/preparation_scheduler.dart` 里把现有 `schedule` 重命名为 `scheduleSegment`（保持逻辑不变，参数 `targetDate` 改名 `segmentEnd` 以表意），并保留 `schedule` 旧名为别名转发，避免破其他调用：

```dart
  static List<({String key, DateTime startDate, DateTime endDate})> scheduleSegment({
    required List<PreparationTemplatePhase> phases,
    required DateTime today,
    required DateTime segmentEnd,
  }) {
    // 原 schedule 逻辑，targetDate -> segmentEnd
  }

  // 兼容旧调用（generator 改造前的过渡）。
  static List<({String key, DateTime startDate, DateTime endDate})> schedule({
    required List<PreparationTemplatePhase> phases,
    required DateTime today,
    required DateTime targetDate,
  }) => scheduleSegment(phases: phases, today: today, segmentEnd: targetDate);
```

- [ ] **Step 4: 写 generator 分段测试**

追加到 `test/domain/services/preparation_plan_generator_test.dart`：

```dart
test('窗口型生成：所有任务 dueDate <= targetDate', () async {
  final gen = PreparationPlanGenerator(
    templateProvider: _FakeProvider(),
    personalizer: _NoopPersonalizer(),
  );
  final plan = await gen.generate(
    competition: _comp(),
    timelineType: CompetitionTimelineType.eventWindow,
    targetDate: DateTime(2026, 5, 20),
    eventEndDate: DateTime(2026, 5, 22),
    defenseDate: null,
    weeklyCommitment: WeeklyCommitment.hours6to10,
    experienceLevel: ExperienceLevel.intermediate,
    calendarToday: DateTime(2026, 5, 1),
  );
  for (final phase in plan.phases) {
    expect(phase.endDate.isAfter(DateTime(2026, 5, 20)), isFalse);
    for (final t in phase.tasks) {
      expect(t.dueDate.isAfter(DateTime(2026, 5, 20)), isFalse);
    }
  }
  expect(plan.timelineType, CompetitionTimelineType.eventWindow);
});

test('提交型有答辩：defense_prep 落在 targetDate+1..defenseDate', () async {
  final gen = PreparationPlanGenerator(
    templateProvider: _FakeProvider(),
    personalizer: _NoopPersonalizer(),
  );
  final plan = await gen.generate(
    competition: _comp(),
    timelineType: CompetitionTimelineType.submission,
    targetDate: DateTime(2026, 5, 30),
    eventEndDate: null,
    defenseDate: DateTime(2026, 6, 10),
    weeklyCommitment: WeeklyCommitment.hours6to10,
    experienceLevel: ExperienceLevel.intermediate,
    calendarToday: DateTime(2026, 5, 1),
  );
  final defensePhase = plan.phases.firstWhere((p) => p.key == 'defense_prep');
  expect(defensePhase.startDate.isAfter(DateTime(2026, 5, 30)), isTrue);
  expect(defensePhase.endDate, DateTime(2026, 6, 10));
});
```

`_FakeProvider` 实现 `PreparationTemplateProvider.load` 返回 `defaultPreparationTemplate(timelineType)`；`_NoopPersonalizer` 返回 `Failure(ServerException())`。

- [ ] **Step 5: 运行测试确认失败**

Run: `flutter test test/domain/services/preparation_plan_generator_test.dart`
Expected: FAIL（generate 签名变了）。

- [ ] **Step 6: 改 generator generate**

改 `lib/domain/services/preparation_plan_generator.dart` 的 `generate` 签名：

```dart
  Future<PreparationPlan> generate({
    required CompetitionSnapshot competition,
    required CompetitionTimelineType timelineType,
    required DateTime targetDate,
    DateTime? eventEndDate,
    DateTime? defenseDate,
    required WeeklyCommitment weeklyCommitment,
    required ExperienceLevel experienceLevel,
    required DateTime calendarToday,
    UserProfile? profile,
  }) async {
    final template = await templateProvider.load(
      timelineType: timelineType,
      includeDefense: defenseDate != null,
      category: competition.category,
      competitionId: competition.id,
    );
    // ...beginner 补基础（不变）...

    // 分段：pre-segment = [today, targetDate]；defense-segment = [targetDate+1, defenseDate]
    final prePhases = phases.where((p) => p.key != 'defense_prep').toList();
    final defensePhases = phases.where((p) => p.key == 'defense_prep').toList();

    final preSchedule = PreparationScheduler.scheduleSegment(
      phases: prePhases, today: calendarToday, segmentEnd: targetDate,
    );
    final defenseSchedule = defensePhases.isEmpty || defenseDate == null
        ? const <({String key, DateTime startDate, DateTime endDate})>[]
        : PreparationScheduler.scheduleSegment(
            phases: defensePhases,
            today: targetDate.add(const Duration(days: 1)),
            segmentEnd: defenseDate,
          );

    // 组装 planPhases：pre 段任务 dueDate=seg.endDate clamp [today,targetDate]；
    // defense 段任务 dueDate=seg.endDate clamp [targetDate+1, defenseDate]。
    // overload：pre 必做工时 > pre预算 || defense 必做工时 > defense预算
    final tightSchedule = PreparationScheduler.isTightSchedule(calendarToday, targetDate);
    final overload = _computeOverload(prePhases, preWeeksBudget) ||
        (defensePhases.isNotEmpty && _computeOverload(defensePhases, defenseWeeksBudget));

    return PreparationPlan(
      id: 'pp_${calendarToday.millisecondsSinceEpoch}',
      competition: competition,
      targetDate: targetDate,
      timelineType: timelineType,
      eventEndDate: eventEndDate,
      defenseDate: defenseDate,
      weeklyCommitment: weeklyCommitment,
      experienceLevel: experienceLevel,
      status: PreparationPlanStatus.active,
      phases: planPhases,
      personalizedSummary: globalAdvice,
      createdAt: calendarToday,
      updatedAt: calendarToday,
      tightSchedule: tightSchedule,
      overload: overload,
      revision: 0,
    );
  }
```

预算计算：`preWeeks = max(0, targetDate.difference(today).inDays)/7`，`defenseWeeks = max(0, defenseDate.difference(targetDate).inDays)/7`。`_computeOverload(phases, weeks)` = `requiredHours > hoursPerWeek*weeks`。

- [ ] **Step 7: 扩展 generate DTO + prompt**

改 `lib/data/dto/preparation_plan_dtos.dart` 的 `PreparationPersonalizationRequest`：加 `timelineType`、`eventEndDate`、`defenseDate`、`calendarToday` 字段与 `toJson`（日期用 `CalendarDate.toIsoDay`）。`phaseKeys` 由 generator 传入（含 defense_prep 当且仅当 defenseDate != null）。

改 `lib/data/ai/ai_preparation_personalizer.dart` 的 `_buildUserMessage` 与 `_systemPrompt`：加入 `【日历基准】`、`【时间模型】`、`【赛事窗口】`、`【答辩日】` 段落，prompt 加规则「窗口型任务不越过 targetDate；提交型 defense_prep 仅在答辩日存在时出现」。

- [ ] **Step 8: 运行测试确认通过**

Run: `flutter test test/domain/services/`
Expected: PASS。

- [ ] **Step 9: 修复 generator 调用点**

表单页 [preparation_plan_form_page.dart:97-106](lib/features/preparation/pages/preparation_plan_form_page.dart#L97-L106) 的 `generate(...)` 调用——本 Task 先**临时**传 `timelineType: CompetitionTimelineType.submission, eventEndDate: null, defenseDate: null, calendarToday: today`，让旧表单继续工作。完整向导在 Task P2.6 改。运行 `flutter test test/features/preparation/` 确认通过。

- [ ] **Step 10: Commit**

```bash
git add lib/domain/services/ lib/data/dto/preparation_plan_dtos.dart lib/data/ai/ai_preparation_personalizer.dart lib/features/preparation/pages/preparation_plan_form_page.dart test/domain/services/ test/features/preparation/
git commit -m "feat(preparation): 双段分段排期+generator 适配"
```

---

## Task P2.6：表单向导（时间模型 + 日期选择器接入）

**Files:**
- Modify: `lib/features/preparation/pages/preparation_plan_form_page.dart`
- Test: `test/features/preparation/pages/preparation_plan_form_page_test.dart`

**Interfaces:**
- Produces: 向导 Step 1 选 timelineType + 日期（用 `showPreparationDatePicker`），Step 3 每周投入，生成时传全字段。

- [ ] **Step 1: 写失败测试**

追加到 `test/features/preparation/pages/preparation_plan_form_page_test.dart`：

```dart
testWidgets('选窗口型后用区间选择器选比赛起止', (tester) async {
  // pump 表单，点「窗口型」，断言出现「选择比赛起止日期」入口
  // 点入口后选 5/20–5/22，断言确认可生成
});
testWidgets('选提交型可选答辩日期', (tester) async {
  // 点「提交型」，断言「选择提交 DDL 与答辩」入口
});
```

- [ ] **Step 2: 运行确认失败 → Step 3: 改表单**

把 `preparation_plan_form_page.dart` 的「目标日期」区改为：先 `SegmentedButton<CompetitionTimelineType>`（窗口型/提交型），按类型决定 `_pickDate` 调 `showPreparationDatePicker` 的 `mode`（range / multiAnchor）。`_targetDate` 由 `rangeStart`（窗口型）或 `deadline`（提交型）赋值；`_eventEndDate`/`_defenseDate` 同步保存。提交校验：窗口型 `rangeEnd >= rangeStart` 且 `rangeStart > today`；提交型 `deadline > today` 且 `defense == null || defense > deadline`。

默认 timelineType：用 `CompetitionTimelineDefaults.defaultFor(competition.id)` 预选，未知默认 `submission`。

- [ ] **Step 4: 运行测试通过 + a11y 回归**

Run: `flutter test test/features/preparation/pages/preparation_plan_form_page_test.dart test/features/preparation/pages/preparation_plan_form_page_a11y_test.dart`
Expected: PASS。

- [ ] **Step 5: 上机肉眼验证**

Run: `flutter run`，进备赛表单：选窗口型 → 区间选择器 → 选 5/20–5/22；选提交型 → 多锚点 → DDL 5/30 + 答辩 6/10。生成后进详情页。若无法上机，说明。

- [ ] **Step 6: Commit**

```bash
git add lib/features/preparation/pages/preparation_plan_form_page.dart test/features/preparation/pages/preparation_plan_form_page_test.dart
git commit -m "feat(preparation): 表单向导时间模型+日期选择器接入"
```

---

## Task P2.7：详情页锚点条 + 手工编辑语义适配

**Files:**
- Create: `lib/features/preparation/widgets/preparation_anchor_bar.dart`
- Modify: `lib/features/preparation/pages/preparation_plan_detail_page.dart`
- Test: `test/features/preparation/widgets/preparation_anchor_bar_test.dart`
- Test: `test/features/preparation/pages/preparation_plan_detail_page_test.dart`

**Interfaces:**
- Produces: `PreparationAnchorBar(plan)` 显示窗口/DDL+答辩锚点

- [ ] **Step 1: 写锚点条测试**

Create `test/features/preparation/widgets/preparation_anchor_bar_test.dart`：

```dart
testWidgets('窗口型显示比赛起止', (tester) async {
  final plan = _windowPlan();
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: PreparationAnchorBar(plan: plan))));
  expect(find.textContaining('比赛'), findsOneWidget);
});
testWidgets('提交型有答辩显示 DDL 与答辩', (tester) async {
  final plan = _submissionPlanWithDefense();
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: PreparationAnchorBar(plan: plan))));
  expect(find.textContaining('提交'), findsOneWidget);
  expect(find.textContaining('答辩'), findsOneWidget);
});
```

- [ ] **Step 2: 实现 anchor bar → Step 3: 详情页接入**

Create `lib/features/preparation/widgets/preparation_anchor_bar.dart`：按 `plan.timelineType` 渲染「比赛 5/20–5/22」或「提交 DDL 5/30 · 答辩 6/10」。在详情页 [preparation_plan_detail_page.dart:117](lib/features/preparation/pages/preparation_plan_detail_page.dart#L117) `PreparationCountdown` 之后插入 `PreparationAnchorBar`。

**手工编辑语义适配**（spec §4.5）：详情页 `_changeTargetDate` 改为只重排对应区间——窗口型只重排赛前阶段（保留已完成 dueDate），提交型只重排提交前阶段。`_TaskEditDialog` 的 `lastDate` 按 phase.key 区分：`defense_prep` 用 `[targetDate+1, defenseDate]`，否则 `[today, targetDate]`。把现有 `lastDate: plan.targetDate`（line 162, 193）改为按 phase 计算。

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/features/preparation/`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/features/preparation/widgets/preparation_anchor_bar.dart lib/features/preparation/pages/preparation_plan_detail_page.dart test/features/preparation/widgets/preparation_anchor_bar_test.dart test/features/preparation/pages/preparation_plan_detail_page_test.dart
git commit -m "feat(preparation): 详情页锚点条+手工编辑双段语义"
```

---

# Phase P3：水平诊断

> 依赖：无（独立）。

## Task P3.1：CompetitionCategoryNormalizer

**Files:**
- Create: `lib/domain/services/competition_category_normalizer.dart`
- Test: `test/domain/services/competition_category_normalizer_test.dart`

**Interfaces:**
- Produces: `CompetitionCategoryNormalizer.normalize(String category) -> String`

- [ ] **Step 1: 写失败测试**

Create `test/domain/services/competition_category_normalizer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/services/competition_category_normalizer.dart';

void main() {
  test('别名归一', () {
    expect(CompetitionCategoryNormalizer.normalize('电子信息类'), '电子与信息类');
    expect(CompetitionCategoryNormalizer.normalize('创新创业类'), '综合与创业类');
    expect(CompetitionCategoryNormalizer.normalize('计算机类'), '计算机类');
  });
  test('未知类目原样返回', () {
    expect(CompetitionCategoryNormalizer.normalize('神秘类'), '神秘类');
  });
}
```

- [ ] **Step 2: 运行确认失败 → Step 3: 实现**

Create `lib/domain/services/competition_category_normalizer.dart`:

```dart
class CompetitionCategoryNormalizer {
  const CompetitionCategoryNormalizer._();
  static const _aliases = {
    '电子信息类': '电子与信息类',
    '创新创业类': '综合与创业类',
    '综合创业类': '综合与创业类',
  };
  static String normalize(String category) =>
      _aliases[category.trim()] ?? category.trim();
}
```

- [ ] **Step 4: 通过 → Step 5: Commit**

```bash
git add lib/domain/services/competition_category_normalizer.dart test/domain/services/competition_category_normalizer_test.dart
git commit -m "feat(preparation): 类目别名归一器"
```

---

## Task P3.2：LevelDiagnosis 实体 + Store

**Files:**
- Create: `lib/domain/entities/level_diagnosis.dart`
- Create: `lib/data/local/level_diagnosis_store.dart`
- Test: `test/data/local/level_diagnosis_store_test.dart`

**Interfaces:**
- Produces: `LevelDiagnosis`、`DiagnosisSelectionSource`、`LevelDiagnosisStore`（`get(String categoryKey)`/`save(LevelDiagnosis)`/`clear`，SharedPreferences key `level_diagnosis.v1`）

- [ ] **Step 1: 写失败测试**

Create `test/data/local/level_diagnosis_store_test.dart`:

```dart
test('save/get 按 categoryKey 存取', () async {
  final store = LevelDiagnosisStore(await _store());
  final d = LevelDiagnosis(categoryKey: '计算机类', diagnosedLevel: ExperienceLevel.intermediate,
    effectiveLevel: ExperienceLevel.intermediate, source: DiagnosisSelectionSource.aiAccepted,
    rationale: '...', diagnosedAt: DateTime(2026,6,1), answers: {});
  await store.save(d);
  expect((await store.get('计算机类'))?.effectiveLevel, ExperienceLevel.intermediate);
});
test('损坏数据降级返回 null', () async { /* setMockInitialValues 塞坏数据，get 返回 null */ });
```

- [ ] **Step 2: 运行确认失败 → Step 3: 实现实体 + store**

Create `lib/domain/entities/level_diagnosis.dart`（按 spec §2.5 的类定义，含 `toJson`/`fromJson`，`diagnosedAt` 用 date-time）。
Create `lib/data/local/level_diagnosis_store.dart`（仿 `LocalChatHistoryStore` 模式，`getJsonMap`/`setJsonMap`）。

- [ ] **Step 4: 通过 → Step 5: Commit**

```bash
git add lib/domain/entities/level_diagnosis.dart lib/data/local/level_diagnosis_store.dart test/data/local/level_diagnosis_store_test.dart
git commit -m "feat(preparation): 水平画像实体+Store"
```

---

## Task P3.3：diagnose DTO + 三实现 + Fake handler

**Files:**
- Create: `lib/domain/repositories/preparation_level_diagnoser.dart`
- Create: `lib/data/dto/level_diagnosis_dtos.dart`
- Create: `lib/data/ai/ai_preparation_level_diagnoser.dart`
- Create: `lib/data/http/http_preparation_level_diagnoser.dart`
- Create: `lib/data/mock/fake_preparation_diagnose_backend.dart`
- Modify: `lib/data/mock/fake_backend.dart`（注册 diagnose）
- Modify: `lib/features/preparation/providers/preparation_providers.dart`
- Test: `test/data/ai/ai_preparation_level_diagnoser_test.dart`

**Interfaces:**
- Produces: `PreparationLevelDiagnoser.diagnose(LevelDiagnosisRequest) -> Future<Result<LevelDiagnosisSuggestion>>`

- [ ] **Step 1: 写失败测试**（AI/HTTP/Fake 三路径，仿 `ai_preparation_personalizer_test.dart`）

Create `test/data/ai/ai_preparation_level_diagnoser_test.dart`：

```dart
test('返回 level/rationale/suggestion', () async {
  final llm = _FakeLlm(jsonEncode({'level':'intermediate','rationale':'...','suggestion':'...'}));
  final d = AiPreparationLevelDiagnoser(llm);
  final r = await d.diagnose(_req());
  expect(r, isA<Success<LevelDiagnosisSuggestion>>());
  expect((r as Success).data.level, ExperienceLevel.intermediate);
});
test('非法 level 丢弃为 Failure', () async { /* llm 返回 level:'expert' -> Failure */ });
```

- [ ] **Step 2: 运行确认失败 → Step 3: 实现**

DTO `LevelDiagnosisRequest`/`LevelDiagnosisSuggestion`（level 仅限三值，校验同 personalizer）。`AiPreparationLevelDiagnoser` 用 spec §5.1 prompt，`jsonMode:true, temperature:0.2`。`HttpPreparationLevelDiagnoser` 走 `POST /api/v1/preparation-plans/diagnose` + `guardApi`。Fake handler 返回固定 intermediate。

providers 加 `preparationLevelDiagnoserProvider` 按 `DataSource` 切换。fake_backend.dart `_defaultHandlers` 加 diagnose 路由。

- [ ] **Step 4: 通过 → Step 5: Commit**

```bash
git add lib/domain/repositories/preparation_level_diagnoser.dart lib/data/dto/level_diagnosis_dtos.dart lib/data/ai/ai_preparation_level_diagnoser.dart lib/data/http/http_preparation_level_diagnoser.dart lib/data/mock/fake_preparation_diagnose_backend.dart lib/data/mock/fake_backend.dart lib/features/preparation/providers/preparation_providers.dart test/data/ai/ai_preparation_level_diagnoser_test.dart
git commit -m "feat(preparation): 水平诊断 LLM/HTTP/Fake 三实现"
```

---

## Task P3.4：向导 Step 2 诊断 UI

**Files:**
- Modify: `lib/features/preparation/pages/preparation_plan_form_page.dart`
- Test: `test/features/preparation/pages/preparation_plan_form_page_test.dart`

- [ ] **Step 1: 写失败测试**（无画像时显示 Q1/Q2，调 diagnose，展示结果，接受后 effectiveLevel 生效；有画像时跳过）

- [ ] **Step 2: 运行确认失败 → Step 3: 实现 Step 2**

在表单 Step 1（时间模型）与 Step 3（每周投入）之间插入诊断 Step：读 `LevelDiagnosisStore.get(normalize(category))`，无则显示两个 `SegmentedButton`（参赛经历 / 领域熟悉度），点「诊断」调 `diagnoserProvider`，展示 AI 卡（level+rationale+suggestion）+「接受」/「手动改档」。接受后 `effectiveLevel=diagnosedLevel`、`source=aiAccepted`，存 store。失败显示 P0 错误态 + 允许手选。

- [ ] **Step 4: 通过 + a11y → Step 5: 上机 → Step 6: Commit**

```bash
git add lib/features/preparation/pages/preparation_plan_form_page.dart test/features/preparation/pages/preparation_plan_form_page_test.dart
git commit -m "feat(preparation): 向导 Step2 水平诊断流程"
```

---

# Phase P4a：AI 助手只读建议

> 依赖：P0、P2。

## Task P4a.1：改动卡实体 + DTO + 共享 validator

**Files:**
- Create: `lib/domain/entities/plan_change_card.dart`
- Create: `lib/data/dto/plan_change_card_dtos.dart`
- Create: `lib/domain/services/plan_change_validator.dart`
- Test: `test/domain/services/plan_change_validator_test.dart`

**Interfaces:**
- Produces: `PlanChangeCard`/`PlanChangeSet`/`NewTaskDraft`/`PhaseScheduleDraft`/`ChangeCardType`/`ChangeCardStatus`（按 spec §2.6）；`PlanChangeValidator.validate(PlanChangeSet, PlanSnapshot) -> List<PlanChangeCard>`（标 rejected）

- [ ] **Step 1: 写失败测试**

Create `test/domain/services/plan_change_validator_test.dart`:

```dart
test('deleteTask 必做任务标记 rejected', () {
  final cards = PlanChangeValidator.validate(_changeSet([
    _card(type: ChangeCardType.deleteTask, targetTaskId: 'task_required'),
  ]), _snapshotWithRequiredTask());
  expect(cards.first.status, ChangeCardStatus.rejected);
  expect(cards.first.rejectionCode, 'required_task_delete_forbidden');
});

test('moveTask 日期越界标记 rejected', () {
  // 提交型非 defense_prep 任务 newDate > targetDate -> rejected
});

test('超过5张只保留前5张', () {
  final cards = List.generate(7, (i) => _adviceCard());
  final result = PlanChangeValidator.validate(_changeSet(cards), _snapshot());
  expect(result, hasLength(5));
});

test('reschedulePhase 与未列出阶段冲突整张拒绝', () { /* ... */ });

test('addTask estimatedHours 越界 rejected', () { /* hours=0 / 201 */ });
```

- [ ] **Step 2: 运行确认失败 → Step 3: 实现实体 + DTO + validator**

实体按 spec §2.6 定义。`PlanChangeValidator` 实现 spec §3.5 全部规则：max 5、target 存在性、deleteTask 必做拦截、addTask 字段、各 timelineType 日期范围、已完成任务不可移/删、phaseSchedule 合并后查重叠/反转/越界。返回的卡 `status` 为 `pending` 或 `rejected`（带 `rejectionCode`/`rejectionReason`）。

- [ ] **Step 4: 通过 → Step 5: Commit**

```bash
git add lib/domain/entities/plan_change_card.dart lib/data/dto/plan_change_card_dtos.dart lib/domain/services/plan_change_validator.dart test/domain/services/plan_change_validator_test.dart
git commit -m "feat(preparation): 改动卡实体+DTO+共享validator"
```

---

## Task P4a.2：assistant 三实现 + Fake handler

**Files:**
- Create: `lib/domain/repositories/preparation_plan_assistant.dart`
- Create: `lib/data/ai/ai_preparation_plan_assistant.dart`
- Create: `lib/data/http/http_preparation_plan_assistant.dart`
- Create: `lib/data/mock/fake_preparation_assistant_backend.dart`
- Modify: `lib/data/mock/fake_backend.dart`
- Modify: `lib/features/preparation/providers/preparation_providers.dart`
- Test: `test/data/ai/ai_preparation_plan_assistant_test.dart`

**Interfaces:**
- Produces: `PreparationPlanAssistant.suggestChanges(PlanAssistantRequest) -> Future<Result<AssistantReply>>`；`AssistantReply` 含 `reply:String` + `PlanChangeSet`（已过 validator）

- [ ] **Step 1: 写失败测试**（AI 返回原始 JSON → 经 validator → AssistantReply；越界卡标 rejected 仍返回）

- [ ] **Step 2: 运行确认失败 → Step 3: 实现**

`AiPreparationPlanAssistant`：用 spec §5.3 prompt，`jsonMode:true, temperature:0.3`，原始 JSON → `PlanChangeSetDto.fromJson` → `PlanChangeValidator.validate(snapshot)` → `AssistantReply`。`HttpPreparationPlanAssistant` 走 `POST /api/v1/preparation-plans/{id}/assistant`。Fake handler 返回含 moveTask+addTask 的样例。

providers 加 `preparationPlanAssistantProvider`。fake_backend 注册 assistant 路由。

- [ ] **Step 4: 通过 → Step 5: Commit**

```bash
git add lib/domain/repositories/preparation_plan_assistant.dart lib/data/ai/ai_preparation_plan_assistant.dart lib/data/http/http_preparation_plan_assistant.dart lib/data/mock/fake_preparation_assistant_backend.dart lib/data/mock/fake_backend.dart lib/features/preparation/providers/preparation_providers.dart test/data/ai/ai_preparation_plan_assistant_test.dart
git commit -m "feat(preparation): AI 助手 LLM/HTTP/Fake 三实现"
```

---

## Task P4a.3：AssistantTurn + 历史存储

**Files:**
- Create: `lib/domain/entities/assistant_turn.dart`
- Create: `lib/data/local/assistant_history_store.dart`
- Test: `test/data/local/assistant_history_store_test.dart`

**Interfaces:**
- Produces: `AssistantTurn`、`AssistantHistoryStore`（`list(planId)`/`append(planId, turn)`/`clear(planId)`，key `preparation_assistant_history.v1`，每计划保留最近 20 轮）

- [ ] **Step 1: 写失败测试**（append/list、20 轮截断、clear、删除计划联动——后者在仓库 delete 时调用 `assistantHistoryStore.clear(id)`，测试 mock）

- [ ] **Step 2: 运行确认失败 → Step 3: 实现**（`AssistantTurn` 含 userMessage/reply/PlanChangeSet/各卡最终状态；store 仿 `LocalChatHistoryStore`）

- [ ] **Step 4: 通过 → Step 5: Commit**

```bash
git add lib/domain/entities/assistant_turn.dart lib/data/local/assistant_history_store.dart test/data/local/assistant_history_store_test.dart
git commit -m "feat(preparation): 助手历史独立store"
```

---

## Task P4a.4：AssistantTurnMessageMapper

**Files:**
- Create: `lib/features/preparation/widgets/assistant_turn_message_mapper.dart`
- Test: `test/features/preparation/widgets/assistant_turn_message_mapper_test.dart`

**Interfaces:**
- Produces: `AssistantTurnMessageMapper.toMessages(AssistantTurn turn, String planId) -> List<ChatMessage>`（确定性 ID `planId+turnId+role`，不持久化）

- [ ] **Step 1: 写失败测试**（映射 user+assistant 两条；recommendations 空；ID 稳定；role/content/status 正确）

- [ ] **Step 2: 运行确认失败 → Step 3: 实现**

```dart
class AssistantTurnMessageMapper {
  static List<ChatMessage> toMessages(AssistantTurn turn, String planId) => [
    ChatMessage(id: '${planId}_${turn.id}_user', role: ChatRole.user,
      content: turn.userMessage, createdAt: turn.createdAt,
      relatedRecommendations: const [], status: ChatMessageStatus.done),
    ChatMessage(id: '${planId}_${turn.id}_assistant', role: ChatRole.assistant,
      content: turn.reply, createdAt: turn.createdAt,
      relatedRecommendations: const [],
      status: turn.error ? ChatMessageStatus.error : ChatMessageStatus.done),
  ];
}
```

- [ ] **Step 4: 通过 → Step 5: Commit**

```bash
git add lib/features/preparation/widgets/assistant_turn_message_mapper.dart test/features/preparation/widgets/assistant_turn_message_mapper_test.dart
git commit -m "feat(preparation): 助手轮次消息映射器"
```

---

## Task P4a.5：助手抽屉 UI + 卡片渲染（只读）

**Files:**
- Create: `lib/features/preparation/widgets/assistant_drawer.dart`
- Create: `lib/features/preparation/widgets/plan_change_card_view.dart`
- Modify: `lib/features/preparation/pages/preparation_plan_detail_page.dart`（加浮动「AI 助手」按钮）
- Test: `test/features/preparation/widgets/assistant_drawer_test.dart`

**Interfaces:**
- Produces: `PreparationAssistantDrawer`（ConsumerStatefulWidget，输入消息 → 调 assistant → 渲染 reply + change cards，**接受按钮暂不开放**/灰显）

- [ ] **Step 1: 写失败测试**（输入消息 → mock assistant 返回 2 卡 → 渲染 reply 全宽 + 2 卡 + 卡显示 summary/rationale；接受按钮禁用）

- [ ] **Step 2: 运行确认失败 → Step 3: 实现**

抽屉：`ChatMessageBubble`（经 mapper）渲染历史 + 当前轮；下方 `PlanChangeCardView` 横滑卡列表。controller 固定 `basePlanRevision = plan.revision`。详情页右下 `FloatingActionButton`（icon `auto_awesome`）`showModalBottomSheet` 打开抽屉。

- [ ] **Step 4: 通过 + a11y → Step 5: 上机（只读发消息看卡片）→ Step 6: Commit**

```bash
git add lib/features/preparation/widgets/assistant_drawer.dart lib/features/preparation/widgets/plan_change_card_view.dart lib/features/preparation/pages/preparation_plan_detail_page.dart test/features/preparation/widgets/assistant_drawer_test.dart
git commit -m "feat(preparation): AI 助手抽屉+改动卡只读渲染"
```

---

# Phase P4b：原子应用

> 依赖：P4a、P2.2。

## Task P4b.1：PlanChangeApplier

**Files:**
- Create: `lib/domain/services/plan_change_applier.dart`
- Test: `test/domain/services/plan_change_applier_test.dart`

**Interfaces:**
- Produces: `PlanChangeApplier.applyCard({required PreparationPlan plan, required PlanChangeCard card, required int expectedRevision}) -> ApplyResult`；`ApplyResult` 含 `PreparationPlan? newPlan`/`bool applied`/`stale`/`error`

- [ ] **Step 1: 写失败测试**

Create `test/domain/services/plan_change_applier_test.dart`:

```dart
test('moveTask 改 dueDate', () { /* apply -> task.dueDate == newDate */ });
test('addTask 生成唯一 ID + kind=userAdded', () { /* apply -> 新任务 id 非空, kind==userAdded */ });
test('deleteTask 移除目标任务', () {});
test('appendAdvice 追加不覆盖', () { /* 原 advice 保留 + 换行 + 新 */ });
test('reschedulePhase 保留已完成 dueDate，未完成 clamp', () {});
test('expectedRevision 不匹配返回 stale', () {});
test('重复 apply 同卡幂等', () { /* 已 applied 直接返回既有 */ });
```

- [ ] **Step 2: 运行确认失败 → Step 3: 实现**

`PlanChangeApplier.applyCard`：先校验 `plan.revision == expectedRevision`，不等返回 `stale=true`；再调 `PlanChangeValidator` 复校该卡；按 type 生成新不可变 plan。`addTask` 的 ID 用 `'u_${plan.revision}_${card.id}'` 保证幂等（同卡同 plan revision 产同 ID）。`appendAdvice` 用 `\n` 追加到 `personalizedAdvice` 或 `personalizedSummary`。

- [ ] **Step 4: 通过 → Step 5: Commit**

```bash
git add lib/domain/services/plan_change_applier.dart test/domain/services/plan_change_applier_test.dart
git commit -m "feat(preparation): 改动卡原子应用器"
```

---

## Task P4b.2：接受/拒绝交互 + stale 检测

**Files:**
- Modify: `lib/features/preparation/widgets/assistant_drawer.dart`
- Modify: `lib/features/preparation/widgets/plan_change_card_view.dart`
- Test: `test/features/preparation/widgets/assistant_drawer_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
testWidgets('接受 moveTask 写回计划并刷新', (tester) async { /* tap 接受 -> plan repo.save 被调 -> 卡变 applied */ });
testWidgets('手工编辑后剩余卡变 stale', (tester) async { /* revision 变 -> 剩余 pending 卡显示 stale 提示 */ });
testWidgets('拒绝后卡标 declined 折叠', (tester) async {});
testWidgets('保存失败卡保持 pending', (tester) async { /* repo 抛 ConflictException -> 卡仍 pending + 错误 */ });
```

- [ ] **Step 2: 运行确认失败 → Step 3: 实现接受流程**

`PlanChangeCardView` 接受按钮（pending 时启用，保存时禁用防重）：点接受 → `PlanChangeApplier.applyCard(plan, card, expectedRevision)` → 若 stale 把本 change set 剩余 pending 卡标 stale；若 applied → `repo.save(newPlan)`（compare-and-set）→ 成功更新 `expectedRevision = newPlan.revision` + 卡标 applied；失败（ConflictException）卡保持 pending + 显示错误。拒绝 → 标 declined 折叠。写回 `AssistantHistoryStore`（更新该 turn 卡状态）。

- [ ] **Step 4: 通过 + a11y → Step 5: 上机（端到端：发消息 → 接受卡 → 看日历更新）→ Step 6: Commit**

```bash
git add lib/features/preparation/widgets/assistant_drawer.dart lib/features/preparation/widgets/plan_change_card_view.dart test/features/preparation/widgets/assistant_drawer_test.dart
git commit -m "feat(preparation): 改动卡接受/拒绝+stale检测"
```

---

# Phase C：契约收口

## Task C.1：OpenAPI + api-contract.md + Fake 注册收口

**Files:**
- Modify: `docs/openapi.yaml`
- Modify: `docs/api-contract.md`
- Verify: `lib/data/mock/fake_backend.dart` 三端点全注册

- [ ] **Step 1: 同步 OpenAPI**

把 diagnose / generate（扩展入参）/ assistant 三端点的 request/response schema 写进 `docs/openapi.yaml`：枚举、必填字段、nullable、`maxItems:5`、日期 `format:date`、审计时间 `format:date-time`、rejection code。

- [ ] **Step 2: 同步 api-contract.md**

- [ ] **Step 3: 确认 Fake 注册三端点**

Run: `flutter test test/data/mock/`
确认 generate/diagnose/assistant 三端点在 fake_backend 已注册，未注册路径返回 404。

- [ ] **Step 4: Commit**

```bash
git add docs/openapi.yaml docs/api-contract.md
git commit -m "docs(api): 备赛三端点 OpenAPI 契约"
```

---

## Task C.2：全量测试 + 人工验证

- [ ] **Step 1: 全量 targeted 测试**

Run: `flutter test test/features/preparation/ test/features/chat/ test/domain/ test/data/local/ test/data/ai/ test/data/http/ test/core/`
Expected: 全 PASS。

- [ ] **Step 2: analyze**

Run: `flutter analyze`
Expected: No issues。

- [ ] **Step 3: 全量 flutter test（注意 Drift hang 已知问题）**

Run: `flutter test`
Expected: 备赛相关全绿。若 Drift 测试 hang（既有问题，非本次引入），明确说明并记录哪些通过。

- [ ] **Step 4: 三场景人工验证**

Run: `flutter run`，验证三条 golden path：
1. 窗口型（ICPC）：表单选窗口型 + 区间 → 生成 → 详情页锚点条「比赛 X–Y」→ 助手发消息 → 接受 moveTask → 日历更新。
2. 无答辩提交型：提交型无答辩 → 无 defense_prep → 助手接受 addTask。
3. 有答辩提交型：提交型 + 答辩 → defense_prep 落 DDL 后 → 助手接受 reschedulePhase。

验证浅色/深色、375px 宽、大字体、键盘遮挡、抽屉关闭重开历史恢复。若无法上机，逐项说明。

- [ ] **Step 5: 最终 Commit（若 C.1 之后有测试微调）**

```bash
git add -A
git commit -m "test(preparation): 三场景端到端回归"
```

---

## Spec 覆盖自检（实现完成后逐条核对）

- §1 设计目标/原则 → 全 plan 体现
- §2.1 日历日期协议 → Task P1.1
- §2.2 双段时间模型 → Task P2.1
- §2.3 模板筛选 + 分段排期 → Task P2.3/P2.4/P2.5
- §2.4 旧计划迁移 → Task P2.2
- §2.5 水平画像 → Task P3.1/P3.2
- §2.6 改动卡 + 助手历史 + mapper → Task P4a.1/P4a.3/P4a.4
- §3.1 接口矩阵 → Task P3.3/P4a.2
- §3.2 diagnose → Task P3.3
- §3.3 generate 扩展 → Task P2.5
- §3.4 assistant → Task P4a.2
- §3.5 改动卡校验 → Task P4a.1
- §3.6 原子应用 + compare-and-set → Task P2.2/P4b.1/P4b.2
- §3.7 OpenAPI → Task C.1
- §4.1 诊断向导 → Task P3.4
- §4.2 日期选择器 → Task P1.2
- §4.3 详情页锚点 → Task P2.7
- §4.4 助手改动卡 UI → Task P4a.5/P4b.2
- §4.5 手工编辑语义 → Task P2.7
- §4.6 P0 气泡错误态 → Task P0.1/P0.2
- §5 prompts → Task P3.3/P2.5/P4a.2
- §6 测试策略 → 各 Task 内
- §7 实现分期 → P0/P1/P2/P3/P4a/P4b/C 顺序一致
