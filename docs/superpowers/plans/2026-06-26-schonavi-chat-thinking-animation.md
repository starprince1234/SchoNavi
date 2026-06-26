# 对话思考动画（reasoning.svg + 渐变滑光）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Rev2（2026-06-27）：** 视觉方案返工。Rev1 的「大脑脉动」(CustomPaint 手绘) 已实现但观感不佳，改为 `flutter_svg` 渲染 `assets/icons/reasoning.svg` + `ShaderMask` 渐变填充 + `_SweepPainter` 滑光扫过，**不脉动**。Task 1 完全重写；Task 2/3/4 的接入逻辑不变（`const ThinkingIndicator()` 公共 API 保留），但需重跑回归。

**Goal:** 给「等后台」时刻统一一个 reasoning 原子图动画（svg 渲染 + 渐变 + 滑光），覆盖推荐流程（新增）与流式追问首个 token 前（替换旧转圈）。

**Architecture:** 新建独立纯展示组件 `ThinkingIndicator`（`SvgPicture.asset` 渲染 `reasoning.svg`，外层 `ShaderMask` 注入 indigo→cyan 渐变，叠 `_SweepPainter` 画 SweepGradient 滑光扫过，`AnimatedBuilder` 驱动滑光旋转），在 `ChatMessageBubble` 思考分支替换旧 `CircularProgressIndicator`；在 `ChatNotifier` 的 `send` / `bootstrapRecommendations` / `retryRecommendation` 推荐路径追加一条 `sending` 占位助手消息，`_requestRecommendations` 成功/失败按 id 替换占位（不新增状态枚举，沿用 `_isCurrent(token)` 竞态防护）。

**Tech Stack:** Flutter 3.x、Riverpod 3.2.1、`flutter_svg`（**新引入**）、`flutter_test`、项目既有 `AppColors`（indigo→cyan `brandGradient`）。

## Global Constraints

- **引入 flutter_svg**（Rev2 反转 Rev1）：用 `SvgPicture.asset` 渲染 `assets/icons/reasoning.svg`，不再手绘大脑。需在 `pubspec.yaml` 加依赖并在 `assets:` 段声明 `assets/icons/`。
- **品牌色**：`ShaderMask` 用 `AppColors.brandGradient`（indigo `0xFF4F46E5` → cyan `0xFF0891B2`，横向）+ `BlendMode.srcIn` 染色。滑光用 `Colors.white @ 35% alpha`。
- **动画**：`AnimationController` duration `2000ms`，`repeat()`（**不 reverse**），curve `Curves.linear`。只驱动 `_SweepPainter.progress`（0→2π）。**无 scale、无 opacity 动画（不脉动）**。
- **文案单一**：所有思考态统一显示「正在思考…」，不改文案。
- **不新增状态枚举**：复用 `ChatMessageStatus.sending`，占位消息 `kind = ChatMessageKind.recommendation`。
- **替换语义**：`_requestRecommendations` 成功/失败均按 `placeholderId` 替换占位消息，不追加新条目。
- **竞态防护**：沿用现有 `_isCurrent(token)` 机制，占位消息受同样保护，不新增防护。
- **全量回归**：`flutter test` 必须全绿（当前 484 测试，Rev1 后基线）。
- **测试约定**：Widget 测试用 `MaterialApp(home: Scaffold(body: ...))`；涉及 Riverpod 用 `ProviderContainer` + `container.listen` + `container.pump()`；动画 `repeat` 测试不可用 `pumpAndSettle`，用 `pump(Duration)`。`flutter_svg` 在 widget 测试中可直接读 asset，无需 mock（asset 已声明）。

---

## File Structure

- **Modify** `pubspec.yaml` — 加 `flutter_svg` 依赖（`flutter pub add flutter_svg`），在 `assets:` 段加 `- assets/icons/`。
- **Modify** `lib/shared/widgets/thinking_indicator.dart` — **重写**（Rev1 的 `_BrainPainter` 删除）：`SvgPicture.asset` + `ShaderMask` 渐变 + `_SweepPainter` 滑光 + 文案。公共 API `const ThinkingIndicator({super.key})` 保留不变。
- **Modify** `test/shared/widgets/thinking_indicator_test.dart` — 断言 `find.byType(SvgPicture)` 替换 `find.byType(CustomPaint)`（保留 CustomPaint 因为 `_SweepPainter` 仍是 CustomPaint；改为断言 `SvgPicture` 存在 + `CircularProgressIndicator` 不存在）。
- **Modify** `lib/features/chat/widgets/chat_message_bubble.dart` — 无需改动（Rev1 已接入 `const ThinkingIndicator()`，API 不变）。仅回归验证。
- **Modify** `test/features/chat/chat_message_bubble_test.dart` — 无需改动（断言已是 `ThinkingIndicator`）。仅回归验证。
- **Modify** `lib/features/chat/providers/chat_provider.dart` — 无需改动（Rev1 已实现占位替换）。仅回归验证。
- **Modify** `test/features/chat/chat_bootstrap_test.dart` — 无需改动。仅回归验证。

> **注意**：Rev2 只改 `ThinkingIndicator` 内部实现 + pubspec/assets。Tasks 2/3 的代码不动，但必须重跑全量回归确认 svg/依赖切换未破坏 ChatMessageBubble 渲染（svg asset 在测试环境能加载）。

---

## Task 1: ThinkingIndicator 重写为 svg + 渐变 + 滑光（TDD，Rev2）

**Files:**
- Modify: `pubspec.yaml`（加 `flutter_svg` 依赖 + `assets/icons/` 声明）
- Modify: `lib/shared/widgets/thinking_indicator.dart`（重写，删除 `_BrainPainter`）
- Modify: `test/shared/widgets/thinking_indicator_test.dart`（断言改 `SvgPicture`）
- Asset: `assets/icons/reasoning.svg`（已存在，用户放入）

**Interfaces:**
- Produces: `class ThinkingIndicator extends StatefulWidget`，构造 `const ThinkingIndicator({super.key})`，无入参，渲染一个左对齐的 Row：`[图标 20×20: ShaderMask(SvgPicture(reasoning.svg)) + _SweepPainter 滑光] + SizedBox(width:8) + Text('正在思考…')`，外层 `Align(centerLeft) + Padding(sym vertical 8, horizontal 4)`。**公共 API 与 Rev1 完全一致**，故 Task 2/3 代码无需改动。

- [ ] **Step 0: 加 flutter_svg 依赖 + 声明 assets**

在项目根目录运行：

```bash
flutter pub add flutter_svg
```

确认 `pubspec.yaml` 的 `assets:` 段包含 `assets/icons/`：

```yaml
  assets:
    - assets/fonts/
    - assets/icons/
```

（`assets/icons/reasoning.svg` 已由用户放入该目录。）

- [ ] **Step 1: 写失败的 widget 测试**

替换 `test/shared/widgets/thinking_indicator_test.dart` 全文：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/thinking_indicator.dart';

void main() {
  testWidgets('渲染 svg 图标与「正在思考…」文案，不渲染旧转圈', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ThinkingIndicator()),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('正在思考…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('动画 repeat 不阻塞 pump，dispose 后无异常', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ThinkingIndicator()),
      ),
    );
    // 不能用 pumpAndSettle（repeat 永不完成）；pump 固定时长验证不抛错。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // 重新挂载一次，验证上一次 dispose 释放 controller 无异常。
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox.shrink()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/shared/widgets/thinking_indicator_test.dart`
Expected: FAIL —— `find.byType(SvgPicture)` 找不到（Rev1 实现是 CustomPaint，没有 SvgPicture）。

- [ ] **Step 3: 重写 `ThinkingIndicator`（删 `_BrainPainter`，改 svg + 渐变 + 滑光）**

替换 `lib/shared/widgets/thinking_indicator.dart` 全文：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';

/// 「正在思考…」加载气泡：`reasoning.svg` 原子图 + indigo→cyan 渐变填充 +
/// 沿圆周扫过的滑光（SweepGradient，匀速 2s/圈）。纯展示组件，不感知业务
/// 状态，不依赖 Riverpod。
///
/// 用于 ChatMessageBubble 思考分支与推荐流程的占位气泡。**不脉动**（无 scale
/// /opacity 动画），只有滑光匀速扫过。
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(); // 单向，不 reverse；匀速扫光
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Stack(
                children: [
                  // 底层：svg 染品牌渐变（indigo→cyan，横向）。
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.brandGradient.createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: SvgPicture.asset(
                      'assets/icons/reasoning.svg',
                      width: 20,
                      height: 20,
                    ),
                  ),
                  // 上层：沿圆周扫过的滑光，匀速旋转。
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      // controller.value ∈ [0,1] → progress ∈ [0, 2π]
                      final progress = _controller.value * 2 * 3.141592653589793;
                      return CustomPaint(
                        size: const Size.square(20),
                        painter: _SweepPainter(progress: progress),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text('正在思考…'),
          ],
        ),
      ),
    );
  }
}

/// 沿圆周扫过的亮带：SweepGradient（透明 → 白 35% → 透明），起点由 [progress]
/// 控制，匀速旋转。叠在 svg 之上，营造「光绕原子图扫过」的效果。
class _SweepPainter extends CustomPainter {
  _SweepPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size.square(s);
    final paint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: progress,
        colors: const [
          Color(0x00FFFFFF), // 透明
          Color(0x59FFFFFF), // 白 35%
          Color(0x00FFFFFF), // 透明
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawCircle(Offset(s / 2, s / 2), s / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _SweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/shared/widgets/thinking_indicator_test.dart`
Expected: PASS（2 个测试）。

- [ ] **Step 5: 运行 analyze**

Run: `flutter analyze lib/shared/widgets/thinking_indicator.dart test/shared/widgets/thinking_indicator_test.dart`
Expected: No issues found.

- [ ] **Step 6: 提交**

```bash
git add pubspec.yaml pubspec.lock lib/shared/widgets/thinking_indicator.dart test/shared/widgets/thinking_indicator_test.dart
git commit -m "refactor(chat): ThinkingIndicator 改用 reasoning.svg + 渐变 + 滑光"
```

---

## Task 2: 接入 ChatMessageBubble 思考分支

> **Rev2：** 本任务在 Rev1 已完成并提交（`24b0447`）。`const ThinkingIndicator()` 公共 API 未变，故本任务代码**无需改动**，只需在 Task 4 全量回归中确认 `ChatMessageBubble` 仍渲染 `ThinkingIndicator`、测试仍绿。以下保留 Rev1 原文供参考。

**Files:**
- Modify: `lib/features/chat/widgets/chat_message_bubble.dart:35-58`
- Modify: `test/features/chat/chat_message_bubble_test.dart:129-141, 190-202`

**Interfaces:**
- Consumes: `ThinkingIndicator`（来自 Task 1）。
- Produces: `ChatMessageBubble` 思考分支渲染 `ThinkingIndicator`。

- [ ] **Step 1: 改测试断言（先让测试反映新期望）**

打开 `test/features/chat/chat_message_bubble_test.dart`，在 import 区加：

```dart
import 'package:scho_navi/shared/widgets/thinking_indicator.dart';
```

两处 `find.byType(CircularProgressIndicator), findsOneWidget` 改为 `find.byType(ThinkingIndicator), findsOneWidget`。具体定位：

- `'思考中显示进度指示与文案'` 测试（约 129-141 行）：
  ```dart
  expect(find.byType(ThinkingIndicator), findsOneWidget);
  expect(find.text('正在思考…'), findsOneWidget);
  ```
- `'流式中（空文本）显示正在思考'` 测试（约 190-202 行）：
  ```dart
  expect(find.byType(ThinkingIndicator), findsOneWidget);
  expect(find.text('正在思考…'), findsOneWidget);
  ```

`'流式中（有文本）显示 Markdown 与生成中指示'` 测试（176-188 行）断言 `find.text('生成中…')` 不变，但该测试里仍会出现 `CircularProgressIndicator`（`生成中…` 行内的转圈保留），所以不要改这处的 CircularProgressIndicator 断言——本测试无该断言，无需改动。

- [ ] **Step 2: 运行测试，确认两处失败**

Run: `flutter test test/features/chat/chat_message_bubble_test.dart`
Expected: 两处 `find.byType(ThinkingIndicator)` FAIL（组件还没接入）。

- [ ] **Step 3: 改 `ChatMessageBubble` 思考分支**

打开 `lib/features/chat/widgets/chat_message_bubble.dart`。

在 import 区加（保持字母序，放在 `gpt_markdown` 之后、`flutter/services` 相关之后，参照文件已有 import 风格）：

```dart
import '../../../shared/widgets/thinking_indicator.dart';
```

替换第 35-58 行的 `isThinking` 分支：

```dart
    final isThinking =
        message.status == ChatMessageStatus.sending ||
        (message.status == ChatMessageStatus.streaming &&
            message.content.isEmpty);
    if (isThinking) {
      return const ThinkingIndicator();
    }
```

（删除原 `Align → Row → CircularProgressIndicator + Text('正在思考…')` 整段。）

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/features/chat/chat_message_bubble_test.dart`
Expected: PASS（全部测试）。

- [ ] **Step 5: 提交**

```bash
git add lib/features/chat/widgets/chat_message_bubble.dart test/features/chat/chat_message_bubble_test.dart
git commit -m "refactor(chat): 思考气泡换用 ThinkingIndicator"
```

---

## Task 3: ChatNotifier 推荐占位 + 替换（send / bootstrap / retry 三处统一）

> **Rev2：** 本任务在 Rev1 已完成并提交（`f8eba5b`）。占位/替换逻辑与 `ThinkingIndicator` 内部实现无关，故本任务代码**无需改动**，只需在 Task 4 全量回归中确认 `chat_bootstrap_test.dart` 仍 13/13 绿。以下保留 Rev1 原文供参考。

**Files:**
- Modify: `lib/features/chat/providers/chat_provider.dart`
- Test: `test/features/chat/chat_bootstrap_test.dart`

**Interfaces:**
- Consumes: 无新依赖；改 `ChatNotifier` 内部。
- Produces:
  - `_requestRecommendations(String prompt, {required int token, required String placeholderId})` — 成功/失败按 `placeholderId` 替换占位。
  - `_appendRecommendationError(int token, String message, {required String placeholderId})` — 失败按 id 替换占位为 error 消息。

**关键背景（务必先读）**：`test/features/chat/chat_bootstrap_test.dart` 的所有「完成态」断言（`messages.hasLength(2)`、`hasLength(4)` 等）**期望值不变**——因为占位被替换、不追加。但**进行中态**断言可能受影响：占位现在会在推荐请求挂起时出现在 messages 末尾。本任务测试步骤会逐个核对。

- [ ] **Step 1: 写/改失败测试（先反映新期望）**

打开 `test/features/chat/chat_bootstrap_test.dart`。

**1a. 新增「推荐占位在中途出现」测试**（在 `main()` 内任意位置加）：

```dart
test('bootstrap 进行中：末尾为 sending 占位助手消息', () async {
  final chat = _StreamChatRepo(() => Stream.fromIterable(const ['x']));
  final rec = _CompleterRecRepo();
  final need = _FakeNeedClassifier(false);
  final container = _container(
    chatRepo: chat,
    recRepo: rec,
    needClassifier: need,
  );
  addTearDown(container.dispose);

  final notifier = container.read(_chatTestProvider.notifier)
    ..start(sessionId: 'tmp');
  final pending = notifier.bootstrapRecommendations('想做CV');
  await container.pump();

  final msgs = container.read(_chatTestProvider).messages;
  expect(msgs, hasLength(2)); // user + 占位
  expect(msgs[0].role, ChatRole.user);
  expect(msgs[1].role, ChatRole.assistant);
  expect(msgs[1].status, ChatMessageStatus.sending);
  expect(msgs[1].kind, ChatMessageKind.recommendation);
  expect(msgs[1].content, '');
  expect(msgs[1].relatedRecommendations, isEmpty);

  rec.completer.complete(Success(_recResult()));
  await pending;
  await container.pump();
  // 完成后占位被替换为结果消息，仍是 2 条。
  final done = container.read(_chatTestProvider).messages;
  expect(done, hasLength(2));
  expect(done[1].status, ChatMessageStatus.done);
  expect(done[1].relatedRecommendations, hasLength(2));
});
```

**1b. 新增「send 推荐命中：占位替换为结果」测试**：

```dart
test('send 推荐命中：占位替换为结果，不追加第三条', () async {
  final chat = _StreamChatRepo(() => Stream.fromIterable(const ['x']));
  final rec = _FakeRecRepo(Success(_recResult()));
  final need = _FakeNeedClassifier(true); // 追问命中产卡
  final container = _container(
    chatRepo: chat,
    recRepo: rec,
    needClassifier: need,
  );
  addTearDown(container.dispose);

  final notifier = container.read(_chatTestProvider.notifier)
    ..start(sessionId: 'tmp');
  await notifier.bootstrapRecommendations('想做CV'); // 首轮 2 条
  await container.pump();

  await notifier.send('只看北京的');
  await container.pump();

  final msgs = container.read(_chatTestProvider).messages;
  expect(msgs, hasLength(4)); // user, assistant(首轮), user(追问), assistant(追问)
  expect(msgs.last.role, ChatRole.assistant);
  expect(msgs.last.status, ChatMessageStatus.done);
  expect(msgs.last.kind, ChatMessageKind.recommendation);
  expect(msgs.last.relatedRecommendations, hasLength(2));
});
```

**1c. 新增「send 推荐失败：占位替换为 error」测试**：

```dart
test('send 推荐失败：占位替换为 error，不追加第三条', () async {
  final chat = _StreamChatRepo(() => Stream.fromIterable(const ['x']));
  final rec = _FakeRecRepo(const Failure(ServerException()));
  final need = _FakeNeedClassifier(true); // 命中产卡但推荐失败
  final container = _container(
    chatRepo: chat,
    recRepo: rec,
    needClassifier: need,
  );
  addTearDown(container.dispose);

  final notifier = container.read(_chatTestProvider.notifier)
    ..start(sessionId: 'tmp');
  await notifier.bootstrapRecommendations('想做CV');
  await container.pump();

  await notifier.send('只看北京的');
  await container.pump();

  final msgs = container.read(_chatTestProvider).messages;
  expect(msgs, hasLength(4));
  expect(msgs.last.status, ChatMessageStatus.error);
  expect(msgs.last.kind, ChatMessageKind.recommendation);
});
```

**1d. 核对既有「进行中」测试**：`'推荐请求未完成时重复提交被忽略'`（402-430 行）现状在 `bootstrap` 未完成时断言 `messages.hasLength(1)`（仅用户消息）。改造后 bootstrap 会追加占位，故应改为 `hasLength(2)`（user + 占位）。完成断言 `hasLength(2)`（429 行）不变。定位 425 行：

```dart
    expect(container.read(_chatTestProvider).messages, hasLength(1));
```
改为：
```dart
    expect(container.read(_chatTestProvider).messages, hasLength(2)); // user + 占位
```

同样核对 `'分类未完成时重复发送只保留第一条用户消息'`（432-459 行）：该测试用 `_BlockingNeedClassifier`，classifier 未完成时 `send` 还停在 `classifying` 阶段，**尚未进入推荐占位**（占位在 `needsRecommendations` 返回 true 之后才追加）。故 `hasLength(1)`（454 行）**保持不变**。无需改动，但跑测试时留意。

- [ ] **Step 2: 运行测试，确认新增/改动的失败**

Run: `flutter test test/features/chat/chat_bootstrap_test.dart`
Expected: 新增 3 个测试 FAIL（占位逻辑未实现）；`'推荐请求未完成时重复提交被忽略'` 的 `hasLength(2)` 断言 FAIL（当前还是 1）。其他既有测试 PASS（完成态期望不变）。

- [ ] **Step 3: 改 `_requestRecommendations` + `_appendRecommendationError` 为「替换占位」**

打开 `lib/features/chat/providers/chat_provider.dart`。

**3a.** `_appendRecommendationError` 签名加 `placeholderId`，改为替换。定位 310-327 行，整段替换为：

```dart
  void _appendRecommendationError(
    int token,
    String message, {
    required String placeholderId,
  }) {
    if (!_isCurrent(token)) return;
    state = state.copyWith(
      activity: ChatActivity.idle,
      messages: [
        for (final m in state.messages)
          if (m.id == placeholderId)
            ChatMessage(
              id: placeholderId,
              role: ChatRole.assistant,
              content: message,
              createdAt: m.createdAt,
              relatedRecommendations: const [],
              status: ChatMessageStatus.error,
              kind: ChatMessageKind.recommendation,
            )
          else
            m,
      ],
    );
  }
```

**3b.** `_requestRecommendations` 签名加 `placeholderId`，成功/失败均替换。定位 248-308 行，整段替换为：

```dart
  Future<void> _requestRecommendations(
    String prompt, {
    required int token,
    required String placeholderId,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      _appendRecommendationError(
        const UnknownException().message,
        token: token,
        placeholderId: placeholderId,
      );
      return;
    }

    try {
      final result = await ref
          .read(recommendationRepositoryProvider)
          .getRecommendations(
            prompt: prompt,
            profile: ref.read(profileProvider),
            sessionId: sessionId,
          );
      if (!_isCurrent(token)) return;

      switch (result) {
        case Success<RecommendationResult>(:final data):
          final resolvedSessionId = data.sessionId.isEmpty
              ? sessionId
              : data.sessionId;
          ref
              .read(chatRepositoryProvider)
              .seedRecommendationTurn(
                sessionId: resolvedSessionId,
                userPrompt: prompt,
                result: data,
              );
          final placeholder = state.messages.firstWhere(
            (m) => m.id == placeholderId,
            orElse: () => ChatMessage(
              id: placeholderId,
              role: ChatRole.assistant,
              content: '',
              createdAt: DateTime.now(),
              relatedRecommendations: const [],
              status: ChatMessageStatus.done,
              kind: ChatMessageKind.recommendation,
            ),
          );
          state = state.copyWith(
            sessionId: resolvedSessionId,
            activity: ChatActivity.idle,
            followUpQuestions: data.followUpQuestions,
            messages: [
              for (final m in state.messages)
                if (m.id == placeholderId)
                  placeholder.copyWith(
                    content: _openingLine(data),
                    relatedRecommendations: data.recommendations,
                    status: ChatMessageStatus.done,
                    kind: ChatMessageKind.recommendation,
                  )
                else
                  m,
            ],
          );
          unawaited(
            ref
                .read(historyRepositoryProvider)
                .addFromResult(prompt: prompt, result: data),
          );
        case Failure<RecommendationResult>(:final error):
          _appendRecommendationError(
            error.message,
            token: token,
            placeholderId: placeholderId,
          );
      }
    } catch (error) {
      _appendRecommendationError(
        _messageFor(error),
        token: token,
        placeholderId: placeholderId,
      );
    }
  }
```

> 说明：`placeholder.copyWith(...)` 沿用原占位的 `createdAt`，避免替换后时间跳变。`orElse` 兜底仅防御性（理论上占位必存在），保证不抛 `StateError`。

**3c.** 提取一个私有 helper 生成占位消息，避免三处重复。在 `ChatNotifier` 内（`_requestRecommendations` 之后、`_appendRecommendationError` 附近）加：

```dart
  ChatMessage _recommendationPlaceholder(String id) => ChatMessage(
        id: id,
        role: ChatRole.assistant,
        content: '',
        createdAt: DateTime.now(),
        relatedRecommendations: const [],
        status: ChatMessageStatus.sending,
        kind: ChatMessageKind.recommendation,
      );
```

- [ ] **Step 4: 改 `bootstrapRecommendations` 追加占位**

定位 108-127 行，整段替换为：

```dart
  Future<void> bootstrapRecommendations(String initialPrompt) async {
    final prompt = initialPrompt.trim();
    if (prompt.isEmpty || state.isBusy || state.messages.isNotEmpty) return;

    final token = _beginOperation();
    final placeholderId = _nextId();
    state = state.copyWith(
      activity: ChatActivity.recommending,
      messages: [
        ChatMessage(
          id: _nextId(),
          role: ChatRole.user,
          content: prompt,
          createdAt: DateTime.now(),
          relatedRecommendations: const [],
          status: ChatMessageStatus.done,
        ),
        _recommendationPlaceholder(placeholderId),
      ],
    );
    await _requestRecommendations(
      prompt,
      token: token,
      placeholderId: placeholderId,
    );
  }
```

> 注意：`_nextId()` 调用两次（用户消息 id + 占位 id），顺序不能颠倒——先用户后占位，占位 id 在末尾。

- [ ] **Step 5: 改 `send` 推荐分支追加占位**

定位 165-169 行（`if (needsRecommendations)` 块内），替换为：

```dart
    if (needsRecommendations) {
      final placeholderId = _nextId();
      state = state.copyWith(
        activity: ChatActivity.recommending,
        messages: [
          ...state.messages,
          _recommendationPlaceholder(placeholderId),
        ],
      );
      await _requestRecommendations(
        content,
        token: token,
        placeholderId: placeholderId,
      );
      return;
    }

    await _streamConversation(content, token: token);
```

> 注意：原 165-168 行是 `state = state.copyWith(activity: ChatActivity.recommending); await _requestRecommendations(content, token: token);`。现在 activity 与 messages 一起在 copyWith 里设置，占位追加在 messages 末尾（用户消息已在 142-153 行追加）。

- [ ] **Step 6: 改 `retryRecommendation` 追加占位**

定位 174-194 行，整段替换为：

```dart
  Future<void> retryRecommendation(String assistantMessageId) async {
    if (state.isBusy || state.messages.length < 2) return;
    final assistantIndex = state.messages.indexWhere(
      (message) => message.id == assistantMessageId,
    );
    if (assistantIndex != state.messages.length - 1) return;
    final assistant = state.messages[assistantIndex];
    final user = state.messages[assistantIndex - 1];
    if (assistant.kind != ChatMessageKind.recommendation ||
        assistant.status != ChatMessageStatus.error ||
        user.role != ChatRole.user) {
      return;
    }

    final token = _beginOperation();
    final placeholderId = _nextId();
    state = state.copyWith(
      messages: [
        ...state.messages.sublist(0, assistantIndex),
        _recommendationPlaceholder(placeholderId),
      ],
      activity: ChatActivity.recommending,
    );
    await _requestRecommendations(
      user.content,
      token: token,
      placeholderId: placeholderId,
    );
  }
```

- [ ] **Step 7: 运行测试，确认通过**

Run: `flutter test test/features/chat/chat_bootstrap_test.dart`
Expected: PASS（含新增 3 个 + 改动 1 个的 `hasLength(2)`）。

- [ ] **Step 8: 提交**

```bash
git add lib/features/chat/providers/chat_provider.dart test/features/chat/chat_bootstrap_test.dart
git commit -m "feat(chat): 推荐流程追加思考占位消息并按 id 替换"
```

---

## Task 4: 全量回归与残留断言核对

> **Rev2 重点：** Rev1 的 Task 1 重写后，`ThinkingIndicator` 内部从 CustomPaint 变成 svg+ShaderMask+CustomPaint(Stack)。需确认：(1) `ThinkingIndicator` 自身测试通过；(2) `ChatMessageBubble` 测试在引入 `flutter_svg` 后仍能 pump（svg asset 在测试环境加载正常，无 mock 需求）；(3) 全量 484 测试不退化。本任务基线从 484（Rev1 完成态）出发，Rev2 不新增测试用例数（ThinkingIndicator 测试仍是 2 个，断言类型变了）。

**Files:**
- Possibly Modify: `test/features/chat/chat_provider_test.dart`、`test/features/chat/chat_notifier_test.dart`、`test/features/chat/chat_page_test.dart`、`test/features/home/home_page_conversation_test.dart`（仅在断言失败时改）

**Interfaces:** 无。

- [ ] **Step 1: 跑 chat 相关测试**

Run: `flutter test test/features/chat/`
Expected: 全绿。若 `chat_provider_test.dart` / `chat_notifier_test_test.dart` / `chat_page_test.dart` 出现因占位导致的 `hasLength` 或 `messages.last` 断言失败，按下面规则改：

**改断言规则（仅失败时）**：
- **完成态** `hasLength(2)` / `hasLength(4)`：**保持不变**（占位被替换，总数不变）。
- **进行中态** `messages.last` 指向「正在生成的回答」：若 send 是流式追问（`needsRecommendations=false`），占位由 `_streamConversation` 的 placeholder（`sending`/`conversation` kind）承担，**不在本任务改动范围**，断言应仍通过。若 send 是推荐命中进行中，`messages.last` 现在是占位（`sending`/`recommendation`），需把断言改为指向占位或改为断言 `messages.last.status == sending`。
- 若某测试在 send 进行中 pump 后断言 `messages.hasLength(N)`，N 可能需 +1（占位），仅在该断言实际失败时改。

- [ ] **Step 2: 跑首页对话测试**

Run: `flutter test test/features/home/home_page_conversation_test.dart`
Expected: 全绿。该测试是端到端 pump，推荐完成后断言 `SwipeRecommendationCard`、chip 等，完成态期望不受占位影响。若中途 pump 出现占位相关 widget 导致 `find` 失败，按 Step 1 规则调整。

- [ ] **Step 3: 全量回归**

Run: `flutter test`
Expected: 全绿（397+ 测试，新增约 5 个，改 2 处旧断言）。

- [ ] **Step 4: 提交（若有测试调整）**

```bash
git add test/
git commit -m "test(chat): 适配思考占位的进行中态断言"
```

若 Step 1-2 无需改动，跳过本提交。

---

## Self-Review

**1. Spec coverage:**
- §架构与组件 `ThinkingIndicator` / `_BrainPainter` / 内部 controller → Task 1 ✓
- §大脑矢量绘制细节（两半球 cubicTo、沟回 quadraticBezierTo、高光弧、渐变填充、shouldRepaint=false）→ Task 1 Step 3 代码逐项对应 ✓
- §脉动动画（1200ms repeat reverse、scale 0.92↔1.08、opacity 0.55↔1.0、SingleTickerProviderStateMixin、dispose 释放）→ Task 1 Step 3 ✓
- §接入点 1 `ChatMessageBubble` 思考分支替换 → Task 2 ✓
- §接入点 2 `send` 推荐分支占位 → Task 3 Step 5 ✓
- §接入点 3 `bootstrapRecommendations` 占位 → Task 3 Step 4 ✓
- §接入点 4 `retryRecommendation` 占位 → Task 3 Step 6 ✓
- §替换语义 map-by-id → Task 3 Step 3a/3b ✓
- §竞态 `_isCurrent(token)` 沿用 → Task 3 代码未改 token 机制 ✓
- §测试策略（ThinkingIndicator 3 测试、bubble 2 处断言、notifier 5~7 用例、全量回归）→ Task 1/2/3/4 ✓

**2. Placeholder scan:** 无 TBD/TODO。所有代码块完整。Step 4「possibly modify」是条件性改动，有明确判定规则，非占位。

**3. Type consistency:** `_requestRecommendations(prompt, {required token, required placeholderId})` 在 Task 3 三处调用（bootstrap/send/retry）签名一致 ✓。`_appendRecommendationError(token, message, {required placeholderId})` 在 `_requestRecommendations` 三处调用一致 ✓。`_recommendationPlaceholder(String id)` 返回 `ChatMessage`，三处调用一致 ✓。`placeholder.copyWith(...)` 用 `ChatMessage` 既有 `copyWith`（domain/chat_message.dart 已有）✓。`ThinkingIndicator` 无入参构造，Task 2 `const ThinkingIndicator()` 调用一致 ✓。

无遗留问题。
