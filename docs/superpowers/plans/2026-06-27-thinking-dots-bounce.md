# ThinkingIndicator 三点跳跃 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把「正在思考…」尾部的省略号拆成三个独立圆点，赋予错峰上下跳跃动效，其余视觉（图标扫光、文字渐变填充、文字横向亮纹）保持不变。

**Architecture:** 复用现有 2s `AnimationController`（`SingleTickerProviderStateMixin`），不新增 ticker。从 `_controller.value` 派生每点相位，用 `Transform.translate` 偏移（不改布局、无 scale/opacity）。shimmer 继续只覆盖「正在思考」四字，三圆点用品牌渐变填充并自带跳跃。

**Tech Stack:** Flutter / Dart、`AnimationController`、`Transform.translate`、`ShaderMask`、`BoxDecoration(gradient, shape: circle)`、`flutter_test`。

## Global Constraints

- 不新增 `AnimationController`、不切 `TickerProviderStateMixin`（保持 `SingleTickerProviderStateMixin`）。
- 不改 `AppColors`、不改 `_SweepPainter`、不改 `_TextShimmerPainter`、不改图标块。
- 不改 `ThinkingIndicator` 对外 API：`const ThinkingIndicator({super.key})`。
- 仅 `Transform.translate`，不引入 scale/opacity 动画。
- 文案从 `'正在思考…'` 改为 `'正在思考'`（删除 U+2026 `…`），尾部三点由独立圆点 widget 承担。
- 圆点规格：5×5、`AppColors.brandGradient` 填充、`BoxShape.circle`、点间距 `SizedBox(width:3)`、与文字间距 `SizedBox(width:3)`。
- 幅度 5px，错峰 0.2，活跃段占比 60%。
- 测试先红后绿，每个 task 内 commit。

---

## File Structure

- **Modify:** `lib/shared/widgets/thinking_indicator.dart` — 文案改 `'正在思考'`；文案块后追加三点 Row；新增 `_dotOffset(int)` 方法；更新类注释。
- **Modify:** `test/shared/widgets/thinking_indicator_test.dart` — 改既有断言（文案），新增三点存在/样式/跳跃断言。

单一文件对单一测试文件，无新文件、无跨模块改动。

---

### Task 1: 测试先行 —— 文案改「正在思考」并断言三圆点存在与样式

**Files:**
- Modify: `test/shared/widgets/thinking_indicator_test.dart`
- (实现暂不动，本 task 只让测试变红)

**Interfaces:**
- Consumes: `ThinkingIndicator`（既有）、`AppColors.brandGradient`（既有）、`ValueKey<int>`（Flutter 内置）。
- Produces: 测试断言「`find.text('正在思考')`」、「三个 `ValueKey<int>(0/1/2)` 圆点、`BoxShape.circle` + `AppColors.brandGradient`」、「文字 ShaderMask srcIn + foregroundPainter 仍在」。

- [ ] **Step 1: 重写测试文件为最终期望状态**

把 `test/shared/widgets/thinking_indicator_test.dart` 整文件替换为：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/theme/app_colors.dart';
import 'package:scho_navi/shared/widgets/thinking_indicator.dart';

void main() {
  testWidgets('渲染 svg 图标与「正在思考」文案 + 三个品牌渐变圆点', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ThinkingIndicator()),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('正在思考'), findsOneWidget);
    expect(find.text('正在思考…'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // 三个圆点，用 ValueKey<int>(0/1/2) 定位。
    for (var i = 0; i < 3; i++) {
      final dot = find.byKey(ValueKey<int>(i));
      expect(dot, findsOneWidget,
          reason: '第 $i 个圆点应存在（ValueKey<int>($i)）');
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: dot, matching: find.byType(DecoratedBox)).first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle, reason: '圆点 $i 应为圆形');
      expect(decoration.gradient, AppColors.brandGradient,
          reason: '圆点 $i 应染品牌渐变');
    }
  });

  testWidgets('「正在思考」文案染品牌渐变且有亮纹扫过（与图标一致）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ThinkingIndicator()),
      ),
    );

    final text = find.text('正在思考');
    expect(text, findsOneWidget);

    // 文案必须被 ShaderMask（品牌渐变 srcIn）包裹 —— 渐变填充。
    final shaderMask = tester.widget<ShaderMask>(
      find.ancestor(of: text, matching: find.byType(ShaderMask)).first,
    );
    expect(
      shaderMask.blendMode,
      BlendMode.srcIn,
      reason: '文案应被 srcIn 染品牌渐变',
    );

    // 文案上方必须有 CustomPaint(foregroundPainter) 叠加亮纹扫过。
    final customPaints = find
        .ancestor(of: text, matching: find.byType(CustomPaint))
        .evaluate();
    final hasForegroundPainter = customPaints.any((element) {
      final cp = element.widget;
      return cp is CustomPaint && cp.foregroundPainter != null;
    });
    expect(
      hasForegroundPainter,
      isTrue,
      reason: '文案上方应有 CustomPaint.foregroundPainter 绘制移动亮纹',
    );
  });

  testWidgets('三点错峰上下跳跃（波浪式）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ThinkingIndicator()),
      ),
    );

    // 起始帧 v=0：t = (0*2 + i*0.2) % 1 → i=0,1,2 → 0/0.2/0.4 全 ≤0.6 活跃，
    // 但 sin(0)=0、sin(0.2π/0.6)=sin(π/3)≠0、sin(0.4π/0.6)=sin(2π/3)≠0。
    // controller repeat 起点为 0；先 pump 一帧让首帧布局完成。
    await tester.pump();

    // pump 到 v≈0.15（300ms / 2000ms）。此时 i=0: t=0.3 活跃段,
    // u=0.5, dy=-sin(0.5π)*5=-5。非零 → 证明在跳。
    await tester.pump(const Duration(milliseconds: 300));

    final dy0 = _dotDy(tester, 0);
    expect(dy0, isNot(equals(0.0)),
        reason: 'v≈0.15 时 i=0 应处于活跃段，dy 非零（约 -5）');

    // 三点错峰：同一时刻 i=0 与 i=2 相位不同 → dy 不同。
    final dy2 = _dotDy(tester, 2);
    expect(dy0, isNot(equals(dy2)), reason: '错峰 0.2 应使相邻点 dy 不同');
  });

  testWidgets('动画 repeat 不阻塞 pump，dispose 后无异常', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ThinkingIndicator()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox.shrink()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}

/// 读取第 i 个圆点 Transform.translate 的 vertical offset。
double _dotDy(WidgetTester tester, int i) {
  final dot = find.byKey(ValueKey<int>(i));
  final transform = tester.widget<Transform>(
    find.ancestor(of: dot, matching: find.byType(Transform)).first,
  );
  return transform.transform.getTranslation().y;
}
```

- [ ] **Step 2: 运行测试，确认变红（实现尚未改）**

Run: `flutter test test/shared/widgets/thinking_indicator_test.dart`
Expected: FAIL —— `find.text('正在思考')` 找不到（当前仍是 `'正在思考…'`），且 `find.byKey(ValueKey<int>(0))` 找不到。

- [ ] **Step 3: Commit**

```bash
git add test/shared/widgets/thinking_indicator_test.dart
git commit -m "test(thinking): 改文案为「正在思考」并断言三圆点跳跃"
```

---

### Task 2: 实现 —— 拆省略号为三圆点 + 跳跃

**Files:**
- Modify: `lib/shared/widgets/thinking_indicator.dart`

**Interfaces:**
- Consumes: `AppColors.brandGradient`、`_TextShimmerPainter`、`_controller`（既有）。
- Produces: 更新后的 `ThinkingIndicator`，文案 `'正在思考'` 后接三个 `ValueKey<int>(0/1/2)` 圆点，每点 `Transform.translate` 由 `_dotOffset(i)` 驱动。

- [ ] **Step 1: 在文件顶部追加 `dart:math` 导入**

把 [thinking_indicator.dart](lib/shared/widgets/thinking_indicator.dart) 第 1-4 行的导入区改为：

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
```

- [ ] **Step 2: 更新类注释（不再「不脉动」）**

把类注释（第 6-12 行）替换为：

```dart
/// 「正在思考」加载气泡：`reasoning.svg` 原子图 + indigo→cyan 渐变填充 +
/// 沿圆周扫过的滑光（SweepGradient，匀速 2s/圈）。文案「正在思考」同享
/// 渐变填充与横向掠过的亮纹（LinearGradient 平移），与图标视觉语言一致。
/// 尾部三个独立圆点用品牌渐变填充并错峰上下跳跃（波浪式），暗示「思考中」。
/// 纯展示组件，不感知业务状态，不依赖 Riverpod。
///
/// 用于 ChatMessageBubble 思考分支与推荐流程的占位气泡。
```

- [ ] **Step 3: 替换 build 中的文案块为「四字 + 三圆点」**

把当前 build 中文案部分（原第 79-99 行，从 `const SizedBox(width: 8),` 到文案 `ShaderMask` 结束的 `),`）替换为下面整段。注意：图标块（`SizedBox` + `Stack`，原 48-78 行）保持不变，仅替换图标之后的文案部分。

替换目标（old）—— 从图标块结束后的下一行开始，到 build 的 Row children 末尾：

```dart
            const SizedBox(width: 8),
            // 文案同享渐变填充 + 横向掠过的亮纹，与图标视觉一致。
            // 外层 CustomPaint 的 foregroundPainter 画移动亮带（必须在
            // ShaderMask 之外，否则 srcIn 会把白带也染成品牌渐变）。
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  foregroundPainter: _TextShimmerPainter(
                    progress: _controller.value,
                  ),
                  child: child,
                );
              },
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.brandGradient.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const Text('正在思考'),
              ),
            ),
            const SizedBox(width: 3),
            // 尾三点：品牌渐变填充，错峰上下跳跃（波浪式）。仅 translate，
            // 不改布局、无 scale/opacity。
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
                        child: Transform.translate(
                          offset: Offset(0, _dotOffset(i)),
                          child: DecoratedBox(
                            key: ValueKey<int>(i),
                            decoration: const BoxDecoration(
                              gradient: AppColors.brandGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox(width: 5, height: 5),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
```

- [ ] **Step 4: 在 `_ThinkingIndicatorState` 内加 `_dotOffset` 方法**

在 `dispose()` 与 `build()` 之间（或 build 之后、类闭合 `}` 之前）插入：

```dart
  /// 第 i 个圆点的纵向偏移（px，向上为负）。由 `_controller.value`（记为 v）
  /// 派生：2s controller 内每点跑 2 个周期（每秒约 1 跳），三点错峰 0.2 形
  /// 成波浪；每周期 60% 活跃（sin 半波）、40% 静止。
  double _dotOffset(int i) {
    final v = _controller.value;
    final t = (v * 2 + i * 0.2) % 1.0;
    if (t > 0.6) return 0.0;
    final u = t / 0.6;
    return -math.sin(u * math.pi) * 5;
  }
```

- [ ] **Step 5: 运行测试，确认全绿**

Run: `flutter test test/shared/widgets/thinking_indicator_test.dart`
Expected: PASS（4 个 testWidgets 全过）。

- [ ] **Step 6: 跑全量测试，确认无回归**

Run: `flutter test`
Expected: PASS（既有测试不受影响；若 chat_page_test 等引用了旧文案需一并修正——见 Task 3 备选）。

- [ ] **Step 7: Commit**

```bash
git add lib/shared/widgets/thinking_indicator.dart
git commit -m "feat(thinking): 拆省略号为三圆点错峰跳跃，复用 2s 控制器"
```

---

### Task 3: 清查下游 —— 修正任何引用旧文案「正在思考…」的测试

**Files:**
- Possibly Modify: `test/features/chat/chat_page_test.dart` 或其它 `grep` 命中处。

**Interfaces:**
- Consumes: Task 2 的文案变更（`'正在思考'`）。

- [ ] **Step 1: 全仓搜索旧文案引用**

Run: `grep -rn "正在思考" lib/ test/`
Expected: 列出所有命中。预期 [thinking_indicator.dart](lib/shared/widgets/thinking_indicator.dart) 与其测试为 `正在思考`（已改），其余命中若含 `…` 需判断是否断言了旧文案。

- [ ] **Step 2: 若有下游测试断言旧文案，按情况修正**

- 若测试断言「气泡出现」类语义（如 `find.text('正在思考…')`）→ 改为 `find.text('正在思考')`。
- 若测试断言「思考中」状态而非确切文案 → 改用 `find.byType(ThinkingIndicator)` 判定，避免脆性。

无命中则跳过本 task。

- [ ] **Step 3: 跑全量测试**

Run: `flutter test`
Expected: PASS。

- [ ] **Step 4: Commit（若有改动）**

```bash
git add test/
git commit -m "test(chat): 同步思考气泡文案变更"
```

---

## Self-Review

1. **Spec coverage：**
   - 复用 2s 控制器、不新增 ticker → Task 2 Step 3/4（`AnimatedBuilder(animation: _controller)` + `_dotOffset` 用 `_controller.value`）。✓
   - 文案 `'正在思考'` + shimmer 保留 → Task 2 Step 3（文字块 ShaderMask + foregroundPainter 不变，仅删 `…`）。✓
   - 三圆点 5×5、品牌渐变、circle、间距 3 → Task 2 Step 3 + 测试 Task 1 断言。✓
   - `_dotOffset`：错峰 0.2、活跃 60%、幅度 5、sin 半波 → Task 2 Step 4。✓
   - 类注释更新 → Task 2 Step 2。✓
   - 测试：文案、ShaderMask srcIn、foregroundPainter、三点存在/样式、跳跃非零、错峰 dy 不同、dispose 无异常 → Task 1。✓
   - 不做项（不改 AppColors/SweepPainter/TextShimmerPainter/API/scale-opacity）→ Global Constraints + Task 2 仅动文案块与新增方法。✓

2. **Placeholder scan：** 无 TBD/TODO；Task 3 Step 2 给了两种修正路径而非「按需处理」。✓

3. **Type consistency：** `_dotOffset(int i) → double`，Task 1 测试 `_dotDy` 读 `Transform.transform.getTranslation().y`（double），一致；`ValueKey<int>(0/1/2)` 在实现与测试一致；`BoxDecoration.shape/gradient` 字段名一致。✓
