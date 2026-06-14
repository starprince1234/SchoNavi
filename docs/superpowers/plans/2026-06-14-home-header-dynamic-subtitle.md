# 首页头部重构 + 动态副标题 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把首页头部从「三栏挤一行」重排为垂直 Hero 结构（品牌大字标居中 → 切换器居中放大 → 模式副标题），并将副标题改为多句温和文案的动画轮播，动画用策略模式实现三种、默认打字机。

**Architecture:** 新增 `RotatingSubtitle` 组件，内部 `Timer` 在文案列表间循环，把「单句的动画呈现」委托给注入的 `SubtitleAnimationStrategy`（打字机与淡入淡出机制不同，故策略自身负责整段渲染）。`home_page.dart` 头部改为垂直 `Column`，`_TabConfig.title` 升级为 `taglines` 列表。

**Tech Stack:** Flutter / Dart，Material 3，复用 `AppColors`、`SlidingPillSwitch`、`AnimatedEntrance`。

**Note on tests:** 按用户指示测试不在范围内。现有 `test/features/home/home_page_test.dart` 已与工作区代码不一致（断言 `'导师推荐'/'竞赛推荐'`，而当前 `SlidingPillSwitch` 标签为 `'导师'/'竞赛'`），且打字机的持续 `Timer` 会让 `pumpAndSettle` 超时——本计划不修改测试，验证以 `flutter analyze` + 真机/模拟器手动观察为准。

---

## File Structure

- **Create** `lib/shared/widgets/rotating_subtitle.dart` — 动态轮播副标题组件 + 策略接口 + 三个策略实现 + 打字机内部组件。单一职责：把一组文案以可插拔动效轮播展示。
- **Modify** `lib/features/home/pages/home_page.dart` — 头部布局重排；`_TabConfig.title` → `taglines`；引入 `RotatingSubtitle` 与默认策略常量。

---

## Task 1: 创建 RotatingSubtitle 组件与策略

**Files:**
- Create: `lib/shared/widgets/rotating_subtitle.dart`

- [ ] **Step 1: 创建完整组件文件**

写入 `lib/shared/widgets/rotating_subtitle.dart`：

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Strategy that owns the full animated presentation of a single phrase.
///
/// Typewriter and fade transitions work fundamentally differently — one
/// reveals a single phrase character by character, the other cross-fades
/// between two phrases — so each strategy renders the phrase itself rather
/// than sharing a single [AnimatedSwitcher.transitionBuilder].
abstract interface class SubtitleAnimationStrategy {
  /// Builds the animated widget showing [text]. When [text] changes, the
  /// strategy decides how to transition to it.
  Widget build(BuildContext context, String text, TextStyle? style);

  /// How long [text] should stay on screen before the rotation advances.
  Duration holdDurationFor(String text);
}

/// Old phrase slides up and fades out; the new phrase rises in from below.
class FadeSlideStrategy implements SubtitleAnimationStrategy {
  const FadeSlideStrategy();

  @override
  Duration holdDurationFor(String text) => const Duration(seconds: 3);

  @override
  Widget build(BuildContext context, String text, TextStyle? style) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Text(
        text,
        key: ValueKey<String>(text),
        style: style,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Pure opacity cross-fade between phrases.
class CrossfadeStrategy implements SubtitleAnimationStrategy {
  const CrossfadeStrategy();

  @override
  Duration holdDurationFor(String text) => const Duration(seconds: 3);

  @override
  Widget build(BuildContext context, String text, TextStyle? style) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Text(
        text,
        key: ValueKey<String>(text),
        style: style,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Types the phrase out one grapheme at a time with a trailing caret.
class TypewriterStrategy implements SubtitleAnimationStrategy {
  const TypewriterStrategy({
    this.perCharacter = const Duration(milliseconds: 90),
    this.holdAfterTyped = const Duration(milliseconds: 1800),
  });

  final Duration perCharacter;
  final Duration holdAfterTyped;

  @override
  Duration holdDurationFor(String text) =>
      perCharacter * text.characters.length + holdAfterTyped;

  @override
  Widget build(BuildContext context, String text, TextStyle? style) {
    return _TypewriterText(
      text: text,
      style: style,
      perCharacter: perCharacter,
    );
  }
}

/// A rotating subtitle that cycles through [phrases], delegating the per-phrase
/// animation to [strategy]. Respects reduced-motion: when animations are
/// disabled it shows the first phrase statically.
class RotatingSubtitle extends StatefulWidget {
  const RotatingSubtitle({
    super.key,
    required this.phrases,
    required this.strategy,
    this.style,
  });

  final List<String> phrases;
  final SubtitleAnimationStrategy strategy;
  final TextStyle? style;

  @override
  State<RotatingSubtitle> createState() => _RotatingSubtitleState();
}

class _RotatingSubtitleState extends State<RotatingSubtitle> {
  int _index = 0;
  Timer? _timer;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _restart();
  }

  @override
  void didUpdateWidget(RotatingSubtitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.phrases, widget.phrases)) {
      _index = 0;
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    if (_reduceMotion || widget.phrases.length <= 1) return;
    _scheduleNext();
  }

  void _scheduleNext() {
    if (widget.phrases.isEmpty) return;
    final current = widget.phrases[_index];
    _timer = Timer(widget.strategy.holdDurationFor(current), () {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.phrases.length);
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.phrases.isEmpty ? '' : widget.phrases[_index];
    if (_reduceMotion) {
      return Text(text, style: widget.style, textAlign: TextAlign.center);
    }
    return widget.strategy.build(context, text, widget.style);
  }
}

class _TypewriterText extends StatefulWidget {
  const _TypewriterText({
    required this.text,
    required this.style,
    required this.perCharacter,
  });

  final String text;
  final TextStyle? style;
  final Duration perCharacter;

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  Timer? _timer;
  int _chars = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _start();
  }

  void _start() {
    _timer?.cancel();
    _chars = 0;
    _timer = Timer.periodic(widget.perCharacter, (timer) {
      if (!mounted) return;
      if (_chars >= widget.text.characters.length) {
        timer.cancel();
        return;
      }
      setState(() => _chars++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.text.characters.length;
    final shown = widget.text.characters.take(_chars).toString();
    final done = _chars >= total;
    return Text.rich(
      TextSpan(
        text: shown,
        children: [
          if (!done)
            const TextSpan(
              text: '▏',
              style: TextStyle(color: AppColors.coral),
            ),
        ],
      ),
      style: widget.style,
      textAlign: TextAlign.center,
    );
  }
}
```

- [ ] **Step 2: 静态分析**

Run: `flutter analyze lib/shared/widgets/rotating_subtitle.dart`
Expected: `No issues found!`（`.characters`、`listEquals` 均由 `package:flutter/material.dart` 间接导出，无需额外 import）

- [ ] **Step 3: 提交**

```bash
git add lib/shared/widgets/rotating_subtitle.dart
git commit -m "feat(ui): add RotatingSubtitle with pluggable animation strategies"
```

---

## Task 2: 重排首页头部并接入动态副标题

**Files:**
- Modify: `lib/features/home/pages/home_page.dart`

- [ ] **Step 1: 新增 import 与默认策略常量**

在 import 区加入（与现有 widget import 同组）：

```dart
import '../../../shared/widgets/rotating_subtitle.dart';
```

在 `class HomePage` 定义之前、import 区之后，加入顶层常量（后期调研后换动效只改这一行）：

```dart
/// 首页副标题动效。后期可替换为 FadeSlideStrategy() / CrossfadeStrategy()。
const SubtitleAnimationStrategy _kSubtitleStrategy = TypewriterStrategy();
```

- [ ] **Step 2: 把 `_TabConfig.title` 升级为 `taglines`**

将 `_TabConfig` 类（当前含 `final String title;`）整体替换为：

```dart
class _TabConfig {
  const _TabConfig({
    required this.taglines,
    required this.examples,
    required this.quickTags,
  });

  final List<String> taglines;
  final List<String> examples;
  final List<String> quickTags;
}
```

- [ ] **Step 3: 为两个模式填入文案池**

在 `_tabConfigs` 中，把 `_HomeTab.mentor` 的 `title: '用自然语言找到适合你的导师',` 替换为：

```dart
      taglines: [
        '说说你想研究的方向，我帮你找到合适的导师',
        '想做哪个方向的研究？我来帮你找导师',
        '不知道选谁？告诉我你的兴趣就好',
        '地区、方向、阶段，想到什么都可以说',
      ],
```

把 `_HomeTab.competition` 的 `title: '用自然语言找到适合你的竞赛',` 替换为：

```dart
      taglines: [
        '说说你的兴趣，我帮你找到适合的竞赛',
        '想参加什么样的比赛？我来帮你找',
        '还在纠结报哪个？告诉我你擅长什么',
        '时间、方向、组队，想到什么都可以说',
      ],
```

- [ ] **Step 4: 重排头部布局**

在 `build` 内，将从 `AnimatedEntrance(index: 0, ...)`（头部 `Row`）到其后的 `const SizedBox(height: 8)` + `Text(_currentConfig.title, ...)` + `const SizedBox(height: 32)` 这一整段，替换为下面的垂直结构：

```dart
                                AnimatedEntrance(
                                  index: 0,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      children: [
                                        // 顶栏：仅菜单按钮，右对齐。
                                        const SizedBox(
                                          height: 44,
                                          width: double.infinity,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: _HomeMenuButton(),
                                          ),
                                        ),
                                        // 品牌字标，居中 Hero。
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'SchoNavi',
                                            style: textTheme.headlineMedium
                                                ?.copyWith(
                                              color: AppColors.coral,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // 模式切换器，居中放大。
                                        SizedBox(
                                          width: 200,
                                          child: SlidingPillSwitch<_HomeTab>(
                                            values: const [
                                              _HomeTab.mentor,
                                              _HomeTab.competition,
                                            ],
                                            selected: _currentTab,
                                            labels: const ['导师', '竞赛'],
                                            onChanged: (value) {
                                              setState(
                                                () => _currentTab = value,
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        // 随模式轮播的动态副标题（固定高度防跳动）。
                                        SizedBox(
                                          height: 44,
                                          child: Center(
                                            child: RotatingSubtitle(
                                              phrases: _currentConfig.taglines,
                                              strategy: _kSubtitleStrategy,
                                              style: textTheme.bodyMedium
                                                  ?.copyWith(
                                                color: AppColors.inkSoft,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
```

注意：替换后 `_HomeMenuButton` 仍在文件末尾定义、`SlidingPillSwitch` 仍由 line 15 的 import 提供，均无需改动。原头部 `Row` 中左侧 120dp 的胶囊、中间字标、右侧 120dp 菜单三栏结构被本段完全取代。

- [ ] **Step 5: 静态分析**

Run: `flutter analyze lib/features/home/pages/home_page.dart`
Expected: `No issues found!`（确认已无对 `_currentConfig.title` 的残留引用）

- [ ] **Step 6: 提交**

```bash
git add lib/features/home/pages/home_page.dart
git commit -m "feat(ui): restructure home header into vertical hero with rotating subtitle"
```

---

## Task 3: 手动视觉验证

**Files:** 无（仅运行观察）

- [ ] **Step 1: 全量分析**

Run: `flutter analyze`
Expected: 不引入新的 error/warning（既有与本次无关的告警可忽略）。

- [ ] **Step 2: 运行 App 观察**

Run: `flutter run`（或在 IDE 启动到模拟器/真机）
Expected 逐项确认：
- 菜单按钮位于右上角，点击/右边缘滑动均能打开抽屉。
- `SchoNavi` 字标居中放大、coral 色、不溢出（小屏经 `FittedBox` 缩放）。
- 切换器居中、约 200dp 宽，点击 `导师`/`竞赛` 滑块平滑切换。
- 副标题以打字机效果逐字敲出，约停留后自动切换下一句；切到竞赛模式时换成竞赛文案且从第一句重新开始。
- Bento 示例、输入框、快捷标签区域行为与样式不变。

- [ ] **Step 3:（可选）验证策略可换**

把 `_kSubtitleStrategy` 临时改为 `const FadeSlideStrategy();`，热重载确认副标题改为「上滑淡入」效果，确认策略切换为一行改动；随后改回 `const TypewriterStrategy();`。

---

## Self-Review

- **Spec coverage**：① 头部垂直重排（菜单右上→字标→切换器→副标题）= Task 2 Step 4 ✔；② 副标题多句轮播 = Task 2 Step 3 + Task 1 ✔；③ 策略模式三实现、默认打字机、一行可换 = Task 1 + Task 2 Step 1/Task 3 Step 3 ✔；④ 风险（FittedBox 防溢出、reduce-motion、打字机时长动态、切模式重置）= Task 1 代码 + Task 2 Step 4 ✔。
- **Placeholder scan**：无 TBD/TODO，所有代码步骤含完整代码。
- **Type consistency**：`SubtitleAnimationStrategy.holdDurationFor(String)`、`build(context,text,style)`、`RotatingSubtitle(phrases/strategy/style)`、`_TabConfig.taglines`、`_kSubtitleStrategy` 在各任务间一致。
