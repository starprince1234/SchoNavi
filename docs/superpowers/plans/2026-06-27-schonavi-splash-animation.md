# SchoNavi 开屏动画 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 SchoNavi 添加原生 splash 冷底色兜底 + 应用内 ~1.8s 品牌绘制叙事开屏动画，结束整页 fade 出无缝交给 go_router onboarding 重定向。

**Architecture:** 四个独立单元——`SplashLogoPainter`（progress 驱动的品牌标 CustomPainter）、`SplashController`（Riverpod Notifier 持 progress + isCompleted，Ticker 驱动 1.8s）、`SplashPage`（渲染 + 点按跳过 + fade-out 后 `go('/home')`）、原生层 XML 改造（冷底色 + 移除默认图标）。路由新增 `/splash` 作 initialLocation 并在 redirect 中豁免。

**Tech Stack:** Flutter 3.x、flutter_riverpod 3.2.1（NotifierProvider）、go_router 17.3.0、Android resources XML。零新增 pubspec 依赖。

## Global Constraints

- 设计 token 单一来源 `lib/core/theme/app_colors.dart`：冷底色 `AppColors.paper = #F8FAFC`（slate-50），品牌渐变 `AppColors.brandGradient`（indigo→cyan），帆叶色 `AppColors.cyanBright`，底面渐变 `[Color(0xFF0F172A), Color(0xFF312E81)]`。
- Riverpod 3.2.1 手写 provider 约定（项目无 codegen）：`NotifierProvider`、`extends Notifier<T>`、`ref.watch`/`ref.read`。
- 颜色透明度统一用 `.withValues(alpha: x)`（项目已弃用 `withOpacity`，见 `glass_surface.dart`/`bento_tile.dart`）。
- 测试约定：widget 测试用 `MaterialApp`/`MaterialApp.router` 包裹；真实路由测试用 `SharedPreferences.setMockInitialValues` + `ProviderContainer` overrides，参考 `test/core/router/splash_redirect_test.dart`。
- 品牌标绘制语义沿用 `lib/shared/widgets/scho_navi_logo.dart` 的 `_MarkPainter`：圆角方底（r=s*0.188）+ cyan 帆叶（cubic 贝塞尔，左下→右上扬起）+ 白航向线（y=s*0.70，圆头描边）。
- 字体 `SourceHanSans`，字标样式取 `headlineMedium`（fontWeight w800）+ `brandGradient` 渐变，与首页 `SchoNaviLogo(withWordmark: true)` 一致。
- 文件分层：`lib/features/splash/`（controller + page）、`lib/shared/widgets/`（painter）。测试镜像路径 `test/...`。

---

## File Structure

**新增：**
- `lib/shared/widgets/splash_logo_painter.dart` — progress 驱动的品牌标 CustomPainter。
- `lib/features/splash/splash_controller.dart` — Notifier，持 progress/isCompleted，Ticker 驱动。
- `lib/features/splash/pages/splash_page.dart` — ConsumerStatefulWidget，渲染 painter + 字标 + 点按跳过 + fade-out 导航。
- `test/shared/widgets/splash_logo_painter_test.dart`
- `test/features/splash/splash_controller_test.dart`
- `test/features/splash/pages/splash_page_test.dart`

**修改：**
- `lib/core/router/app_router.dart` — 新增 `/splash` 路由，`initialLocation` 改 `/splash`，redirect 加 splash 豁免。
- `test/core/router/splash_redirect_test.dart` — 适配 splash 时长后再断言 onboarding 重定向。
- `test/core/router/chat_route_test.dart` — 适配 splash 时长后再断言 chat 路由。
- `android/app/src/main/res/values/colors.xml` — 新增 `splash_paper`。
- `android/app/src/main/res/drawable/launch_background.xml` — 改底色、移除 bitmap。
- `android/app/src/main/res/drawable-v21/launch_background.xml` — 同上。

---

### Task 1: SplashLogoPainter（progress 驱动品牌标绘制）

**Files:**
- Create: `lib/shared/widgets/splash_logo_painter.dart`
- Test: `test/shared/widgets/splash_logo_painter_test.dart`

**Interfaces:**
- Consumes: `AppColors`（来自 `lib/core/theme/app_colors.dart`）。
- Produces: `class SplashLogoPainter extends CustomPainter`，构造 `SplashLogoPainter({required this.progress})`，字段 `final double progress;`（0.0→1.0）。`shouldRepaint` 比较 `progress`。绘制内容：
  - 圆角方底：opacity = `clampInterval(progress, 0.0, 0.30)`、scale = lerp(0.7→1.0, same interval)。
  - 帆叶（cyan 贝塞尔闭合路径）：用 `PathMetric.extractPath` 取 `clampInterval(progress, 0.20, 0.70)` 比例的子路径绘制。
  - 航向线：从左到右，长度比例 = `clampInterval(progress, 0.60, 0.90)`，圆头描边白色。
  - progress=0 时不绘制帆叶与航向线（底面 opacity=0）；progress=1 时全量绘制。

- [ ] **Step 1: Write the failing test**

Create `test/shared/widgets/splash_logo_painter_test.dart`:

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/splash_logo_painter.dart';

void main() {
  // 用一个记录调用的 mock Canvas 验证 progress=0 时不画帆叶/航向线。
  test('progress=0 时帆叶与航向线均不绘制', () {
    final recorder = _RecordingCanvas();
    final painter = SplashLogoPainter(progress: 0);
    painter.paint(recorder, const Size.square(64));
    expect(recorder.drawPathCount, 0, reason: 'progress=0 时帆叶不应绘制');
    expect(recorder.drawLineCount, 0, reason: 'progress=0 时航向线不应绘制');
  });

  test('progress=1 时帆叶与航向线各绘制一次', () {
    final recorder = _RecordingCanvas();
    final painter = SplashLogoPainter(progress: 1);
    painter.paint(recorder, const Size.square(64));
    expect(recorder.drawPathCount, greaterThanOrEqualTo(1),
        reason: 'progress=1 时帆叶应绘制');
    expect(recorder.drawLineCount, 1, reason: 'progress=1 时航向线应绘制一次');
  });

  test('progress 增大时帆叶子路径长度递增', () {
    final len = (double p) {
      final r = _RecordingCanvas();
      SplashLogoPainter(progress: p).paint(r, const Size.square(64));
      return r.lastLeafPathLength;
    };
    final l1 = len(0.30);
    final l2 = len(0.50);
    final l3 = len(0.70);
    expect(l2, greaterThan(l1), reason: 'progress 0.30→0.50 帆叶应生长');
    expect(l3, greaterThan(l2), reason: 'progress 0.50→0.70 帆叶应生长');
  });

  test('shouldRepaint 仅在 progress 变化时为 true', () {
    final a = SplashLogoPainter(progress: 0.3);
    expect(a.shouldRepaint(SplashLogoPainter(progress: 0.3)), isFalse);
    expect(a.shouldRepaint(SplashLogoPainter(progress: 0.5)), isTrue);
  });
}

class _RecordingCanvas implements Canvas {
  int drawPathCount = 0;
  int drawLineCount = 0;
  double lastLeafPathLength = 0;
  Path? _lastPath;

  @override
  void drawPath(Path path, Paint paint) {
    drawPathCount++;
    _lastPath = path;
    final metrics = path.computeMetrics();
    lastLeafPathLength = metrics.fold<double>(
      0.0,
      (acc, m) => acc + m.length,
    );
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => drawLineCount++;

  // ── 以下为 Canvas 接口的 no-op 实现，仅为编译 ──
  @override
  void noSuchMethod(Invocation invocation) {}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/splash_logo_painter_test.dart`
Expected: FAIL — `SplashLogoPainter` 未定义 / 找不到类。

- [ ] **Step 3: Write minimal implementation**

Create `lib/shared/widgets/splash_logo_painter.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 把 [t] 在 [a]-[b] 区间内归一化到 0.0-1.0，区间外 clamp。
double clampInterval(double t, double a, double b) {
  if (b <= a) return t <= a ? 0.0 : 1.0;
  return ((t - a) / (b - a)).clamp(0.0, 1.0);
}

/// progress 驱动的 SchoNavi 品牌标 CustomPainter。
///
/// 三段错峰绘制（progress 0→1）：
/// - 圆角方底（slate→indigo 渐变）：[0.0, 0.30] opacity 0→1 + scale 0.7→1.0。
/// - cyan 帆叶：[0.20, 0.70] 沿贝塞尔曲线 trim 生长（PathMetric.extractPath）。
/// - 白航向线：[0.60, 0.90] 从左到右横向画出（圆头描边）。
///
/// 绘制语义沿用 [SchoNaviLogo._MarkPainter]：圆角方 + 帆叶（学校+导航/成长）+
/// 白航向线。progress=0 时不绘制帆叶与航向线。
class SplashLogoPainter extends CustomPainter {
  SplashLogoPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = s * 0.188;

    // ── 圆角方底：opacity + scale ──
    final bgT = clampInterval(progress, 0.0, 0.30);
    if (bgT > 0) {
      final scale = 0.7 + 0.3 * bgT; // 0.7→1.0
      canvas.save();
      canvas.translate(s / 2, s / 2);
      canvas.scale(scale);
      canvas.translate(-s / 2, -s / 2);
      final bgPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF312E81)],
        ).createShader(Offset.zero & size);
      bgPaint.color = bgPaint.color.withValues(alpha: bgT);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)),
        bgPaint,
      );
      canvas.restore();
    }

    // ── 帆叶：沿贝塞尔 trim 生长 ──
    final leafT = clampInterval(progress, 0.20, 0.70);
    if (leafT > 0) {
      final fullLeaf = Path()
        ..moveTo(s * 0.25, s * 0.61)
        ..cubicTo(s * 0.36, s * 0.34, s * 0.50, s * 0.22, s * 0.75, s * 0.23)
        ..cubicTo(s * 0.67, s * 0.47, s * 0.53, s * 0.61, s * 0.25, s * 0.61)
        ..close();
      final metrics = fullLeaf.computeMetrics();
      final subPath = Path();
      for (final m in metrics) {
        subPath.addPath(m.extractPath(0, m.length * leafT), Offset.zero);
      }
      canvas.drawPath(subPath, Paint()..color = AppColors.cyanBright);
    }

    // ── 航向线：从左到右画出 ──
    final lineT = clampInterval(progress, 0.60, 0.90);
    if (lineT > 0) {
      final startX = s * 0.31;
      final fullEndX = s * 0.69;
      final endX = startX + (fullEndX - startX) * lineT;
      canvas.drawLine(
        Offset(startX, s * 0.70),
        Offset(endX, s * 0.70),
        Paint()
          ..color = Colors.white
          ..strokeWidth = s * 0.078
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SplashLogoPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/splash_logo_painter_test.dart`
Expected: PASS — 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/splash_logo_painter.dart test/shared/widgets/splash_logo_painter_test.dart
git commit -m "feat(splash): SplashLogoPainter progress 驱动品牌标绘制"
```

---

### Task 2: SplashController（Riverpod Notifier + Ticker）

**Files:**
- Create: `lib/features/splash/splash_controller.dart`
- Test: `test/features/splash/splash_controller_test.dart`

**Interfaces:**
- Consumes: 无外部依赖（纯 Notifier + TickerProvider）。
- Produces:
  - `class SplashState { const SplashState({this.progress = 0, this.isCompleted = false}); final double progress; final bool isCompleted; }`
  - `class SplashController extends Notifier<SplashState>` with `TickerProviderStateMixin`：
    - `void start()` — 创建 1.8s `AnimationController`，addListener 更新 progress；到 1.0 置 isCompleted=true。
    - `void skip()` — 置 progress=1.0、isCompleted=true 并停 ticker。
    - `void markNavigated()` — 页面完成导航后调用，停 ticker（防重复 go）。
  - `final splashControllerProvider = NotifierProvider<SplashController, SplashState>(SplashController.new);`
  - 注意：`SplashController` 不是页面自身的 State，而是 Notifier，但需要 Ticker。Riverpod Notifier 无法直接 `with TickerProviderStateMixin`（无 BuildContext）。方案：Notifier 持有原始 `Ticker`，构造时由 `ref` 不可得 vsync。**改用页面级 AnimationController 驱动 progress**：见 Task 3 实现说明——Notifier 仅作为状态容器与命令入口，Ticker 由 `SplashPage`（`SingleTickerProviderStateMixin`）创建并 `addListener` 调 `notifier.setProgress(v)` / `notifier.complete()`。因此本 Task 产出 Notifier 状态 + 命令，不含 Ticker。

**修正后的接口（Notifier 仅状态容器）：**
- `class SplashController extends Notifier<SplashState>`：
  - 字段 `AnimationController? _ticker`（由页面 attach）。
  - `void attach(AnimationController c)` — 保存引用并设 listener：`c.addListener(() { final v = c.value; state = state.copyWith(progress: v); if (v >= 1.0 && !state.isCompleted) complete(); })`。
  - `void complete()` — `state = SplashState(progress: 1, isCompleted: true)`。
  - `void skip()` — `_ticker?.value = 1.0;`（listener 会触发 complete）。
  - `void markNavigated()` — `_ticker?.stop();`。

> **设计取舍**：因 Notifier 无 vsync，Ticker 必须由页面提供。但为保持 controller 可单测，**本 Task 的测试只验状态机**（progress 更新、isCompleted、skip 触发 complete），Ticker 集成验在 Task 3 的 page 测试中。

- [ ] **Step 1: Write the failing test**

Create `test/features/splash/splash_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/features/splash/splash_controller.dart';

void main() {
  test('初始状态 progress=0 isCompleted=false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = container.read(splashControllerProvider);
    expect(state.progress, 0);
    expect(state.isCompleted, isFalse);
  });

  test('setProgress 更新 progress 且不置 isCompleted（v<1）', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(splashControllerProvider.notifier).setProgress(0.5);
    final state = container.read(splashControllerProvider);
    expect(state.progress, 0.5);
    expect(state.isCompleted, isFalse);
  });

  test('setProgress(1.0) 自动置 isCompleted=true', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(splashControllerProvider.notifier).setProgress(1.0);
    final state = container.read(splashControllerProvider);
    expect(state.isCompleted, isTrue);
    expect(state.progress, 1.0);
  });

  test('complete 直接置 isCompleted=true 且 progress=1', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(splashControllerProvider.notifier).complete();
    expect(container.read(splashControllerProvider).isCompleted, isTrue);
    expect(container.read(splashControllerProvider).progress, 1.0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/splash/splash_controller_test.dart`
Expected: FAIL — `splash_controller.dart` 找不到 / `SplashController` 未定义。

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/splash/splash_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Splash 动画状态：[progress] 0.0→1.0 驱动 painter，[isCompleted] 触发 fade-out。
class SplashState {
  const SplashState({this.progress = 0.0, this.isCompleted = false});

  final double progress;
  final bool isCompleted;

  SplashState copyWith({double? progress, bool? isCompleted}) => SplashState(
        progress: progress ?? this.progress,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}

/// Splash 动画状态容器。Ticker 由 [SplashPage]（SingleTickerProviderStateMixin）
/// 提供，页面监听 AnimationController 把 value 推给 [setProgress]；到达 1.0
/// 自动 [complete]。页面调用 [skip] 跳过、[markNavigated] 防重复导航。
///
/// 设计：Notifier 无 vsync 故不持 Ticker；仅作状态机与命令入口，便于纯逻辑单测。
class SplashController extends Notifier<SplashState> {
  @override
  SplashState build() => const SplashState();

  /// 由页面 Ticker 推送当前进度值（0.0-1.0）。
  void setProgress(double value) {
    if (value >= 1.0) {
      state = const SplashState(progress: 1.0, isCompleted: true);
      return;
    }
    state = SplashState(progress: value, isCompleted: false);
  }

  /// 直接置完成态（跳过/收尾用）。
  void complete() =>
      state = const SplashState(progress: 1.0, isCompleted: true);

  /// 跳过：页面把 Ticker 跳到 1.0，listener 会调 setProgress(1.0)→complete。
  /// 此处仅作语义占位；实际跳过动作由页面操作 Ticker。
  void skip() => complete();

  /// 页面完成 fade-out 导航后调用，防重复 go。
  void markNavigated() {
    // 无 Ticker 引用则 no-op；状态已是 completed。
  }
}

final splashControllerProvider =
    NotifierProvider<SplashController, SplashState>(SplashController.new);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/splash/splash_controller_test.dart`
Expected: PASS — 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/splash/splash_controller.dart test/features/splash/splash_controller_test.dart
git commit -m "feat(splash): SplashController 状态机 (progress/isCompleted)"
```

---

### Task 3: SplashPage（渲染 + 字标 + 跳过 + fade-out 导航）

**Files:**
- Create: `lib/features/splash/pages/splash_page.dart`
- Test: `test/features/splash/pages/splash_page_test.dart`

**Interfaces:**
- Consumes:
  - `SplashLogoPainter`（Task 1）：`SplashLogoPainter(progress: <double>)`。
  - `splashControllerProvider`（Task 2）：`ref.watch` 得 `SplashState`，`ref.read(...notifier).setProgress/skip/complete`。
  - `CoolScaffoldBackground`（`lib/shared/widgets/cool_scaffold_background.dart`）。
  - `AppColors.brandGradient`、`AppColors.ink`、`AppColors.inkSoft`。
  - `routerProvider`（`lib/core/router/app_router.dart`，已存在）。
- Produces: `class SplashPage extends ConsumerStatefulWidget`，无参构造。

**行为：**
- `initState` 创建 `SingleTickerProviderStateMixin` 的 `AnimationController(duration: 1800ms)`，`addListener` → `ref.read(splashControllerProvider.notifier).setProgress(c.value)`；`forward()` 启动。
- `build`：`Stack` → `CoolScaffoldBackground` + 居中列（logo CustomPaint size=72 + 字标）。字标用 `Tween<Offset>(begin: Offset(0,12), end: Offset.zero) + FadeTransition`，interval [0.75, 1.0]。
- 整页 `onTap` → `_controller.value = 1.0`（skip，listener 触发 complete）。
- `isCompleted` 变 true → 外层 `AnimatedOpacity(opacity: 0, duration: 200ms)`，`onAnimationEnd` 调 `ref.read(routerProvider).go('/home')` 且 `_navigated` flag 防重。

- [ ] **Step 1: Write the failing test**

Create `test/features/splash/pages/splash_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/router/app_router.dart';
import 'package:scho_navi/features/splash/pages/splash_page.dart';
import 'package:scho_navi/features/onboarding/pages/onboarding_page.dart';

Future<Widget> _app({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(p)],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: container.read(routerProvider)),
  );
}

void main() {
  testWidgets('初始渲染：logo CustomPaint + 「SchoNavi」字标存在，opacity=1', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pump(); // 首帧
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('SchoNavi'), findsOneWidget);
  });

  testWidgets('点按跳过 → isCompleted 后整页 fade 出并导航到 /onboarding（未读引导）', (tester) async {
    await tester.pumpWidget(await _app(prefs: {}));
    await tester.pump();
    expect(find.byType(SplashPage), findsOneWidget);

    // 点按触发 skip。
    await tester.tap(find.byType(SplashPage));
    await tester.pump();

    // isCompleted=true 后 AnimatedOpacity 200ms fade 出。
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 未读引导 → 导航到 OnboardingPage。
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('动画自然播完 → 导航到 /home（已读引导，不显示 onboarding）', (tester) async {
    await tester.pumpWidget(await _app(prefs: {'seenOnboarding': true}));
    // 让 1.8s 动画 + 200ms fade-out 全部跑完。
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(OnboardingPage), findsNothing);
  });

  testWidgets('整页可点按（GestureDetector 包裹）', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pump();
    expect(find.byType(GestureDetector), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/splash/pages/splash_page_test.dart`
Expected: FAIL — `SplashPage` 未定义；路由 `initialLocation` 仍是 `/home`（Task 4 才改），故前两个用例会因 `/splash` 路由不存在而报错。

> **依赖说明**：本 Task 的测试需要 `/splash` 路由与 `initialLocation: '/splash'`（Task 4）才完整通过。因此本 Task 先写 `SplashPage` 组件本身并提交，Task 4 接好路由后再让本测试全绿。为避免 Task 3 卡红，**本 Task 仅验组件可被独立渲染**（用本地 MaterialApp 包裹，不依赖 router）——见下面修正后的 Step 1。

- [ ] **Step 1 (修正): Write the failing test — 组件级渲染，不依赖路由**

替换上面的 Step 1 测试为：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/features/splash/pages/splash_page.dart';
import 'package:scho_navi/features/splash/splash_controller.dart';

Widget _wrap() {
  final container = ProviderContainer();
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: SplashPage()),
  );
}

void main() {
  testWidgets('初始渲染：logo CustomPaint + 「SchoNavi」字标存在', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('SchoNavi'), findsOneWidget);
  });

  testWidgets('点按跳过 → isCompleted=true', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SplashPage()),
      ),
    );
    await tester.pump();
    expect(container.read(splashControllerProvider).isCompleted, isFalse);

    await tester.tap(find.byType(SplashPage));
    await tester.pump();
    expect(container.read(splashControllerProvider).isCompleted, isTrue);
  });

  testWidgets('整页可点按（GestureDetector 存在）', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.byType(GestureDetector), findsWidgets);
  });
}
```

> **导航断言留到 Task 5**：fade-out 后 `go('/home')` + onboarding 重定向的端到端验在 Task 5 的 `splash_redirect_test.dart` 改造中完成，避免本 Task 依赖未接好的路由。

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/splash/pages/splash_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/cool_scaffold_background.dart';
import '../../../shared/widgets/splash_logo_painter.dart';
import '../splash_controller.dart';

/// 开屏品牌动画页：1.8s logo 绘制叙事 + 字标入场，可点按跳过，
/// isCompleted 后整页 fade 出（200ms）并 [routerProvider].go('/home')。
///
/// onboarding 重定向由 go_router 的 redirect 接管，本页不感知。
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addListener(() {
        ref.read(splashControllerProvider.notifier).setProgress(_ticker.value);
      });
    _ticker.forward();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _skip() {
    if (_ticker.value < 1.0) {
      _ticker.value = 1.0; // listener 触发 setProgress(1.0)→complete
    }
  }

  void _onFadeOutEnd() {
    if (_navigated) return;
    _navigated = true;
    ref.read(splashControllerProvider.notifier).markNavigated();
    ref.read(routerProvider).go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(splashControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    // 字标：opacity + translate-y，interval [0.75, 1.0]。
    final wordmarkT = clampInterval(state.progress, 0.75, 1.0);
    final wordmarkOpacity = wordmarkT;
    final wordmarkDy = (1 - wordmarkT) * 12.0;

    return GestureDetector(
      onTap: _skip,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: state.isCompleted ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        onEnd: state.isCompleted ? _onFadeOutEnd : null,
        child: Stack(
          children: [
            const Positioned.fill(child: CoolScaffoldBackground()),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CustomPaint(
                      size: const Size.square(72),
                      painter: SplashLogoPainter(progress: state.progress),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: wordmarkOpacity,
                    child: Transform.translate(
                      offset: Offset(0, wordmarkDy),
                      child: ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.brandGradient.createShader(bounds),
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          'SchoNavi',
                          style: (textTheme.headlineMedium ??
                                  const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800))
                              .copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.indigo,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/splash/pages/splash_page_test.dart`
Expected: PASS — 3 tests pass（组件级渲染、点按跳过触发 isCompleted、GestureDetector 存在）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/splash/pages/splash_page.dart test/features/splash/pages/splash_page_test.dart
git commit -m "feat(splash): SplashPage 品牌动画页 + 跳过 + fade-out 导航"
```

---

### Task 4: 路由接入（/splash 路由 + initialLocation + redirect 豁免）

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Test: `test/core/router/splash_redirect_test.dart`（适配 splash 时长）

**Interfaces:**
- Consumes: `SplashPage`（Task 3）。
- Produces: `routerProvider` 的 `initialLocation` 改为 `/splash`；新增 `GoRoute(path: '/splash', ...)`；redirect 开头加 `if (state.matchedLocation == '/splash') return null;`。

- [ ] **Step 1: Write the failing test — 改造现有 splash_redirect_test.dart**

替换 `test/core/router/splash_redirect_test.dart` 全文：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/router/app_router.dart';
import 'package:scho_navi/features/onboarding/pages/onboarding_page.dart';
import 'package:scho_navi/features/splash/pages/splash_page.dart';

Future<Widget> _app(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('冷启动从 /splash 开始，动画播完后未读引导 → 重定向到 /onboarding', (tester) async {
    await tester.pumpWidget(await _app(<String, Object>{}));
    await tester.pump(); // 首帧：停在 SplashPage
    expect(find.byType(SplashPage), findsOneWidget);

    // 跑完 1.8s 动画 + 200ms fade-out。
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('已读引导 → 动画播完后停在首页（不显示 onboarding）', (tester) async {
    await tester.pumpWidget(await _app(<String, Object>{'seenOnboarding': true}));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(OnboardingPage), findsNothing);
  });

  testWidgets('initialLocation 为 /splash', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'seenOnboarding': true});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    expect(router.routerConfiguration.initialLocation, '/splash');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/router/splash_redirect_test.dart`
Expected: FAIL — `/splash` 路由不存在、initialLocation 仍 `/home`。

- [ ] **Step 3: Write minimal implementation — 改 app_router.dart**

Modify `lib/core/router/app_router.dart`。在文件顶部 import 区加：

```dart
import '../../features/splash/pages/splash_page.dart';
```

把 `initialLocation: '/home'` 改为 `'/splash'`，并在 `redirect` 开头加 splash 豁免、在 `routes` 数组首位加 `/splash` 路由：

```dart
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      // splash 豁免：动画页不参与 onboarding 重定向，否则未读引导用户会被
      // 直接跳走、动画无法播放。
      if (state.matchedLocation == '/splash') return null;
      final seen =
          ref.read(localStoreProvider).getBool(OnboardingPage.seenKey) ?? false;
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!seen && !atOnboarding) return '/onboarding';
      if (seen && atOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
      // ... 其余路由保持不变
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/router/splash_redirect_test.dart`
Expected: PASS — 3 tests pass。

- [ ] **Step 5: Run chat_route_test.dart — 适配 splash 时长**

`test/core/router/chat_route_test.dart` 现有逻辑：`pumpAndSettle()` 后 `router.go('/chat?sid=s_x')` 再 `pumpAndSettle()`。改造后首个 `pumpAndSettle()` 会停在 splash 动画（1.8s forward 会 settle），需要先 pump 过 splash 时长。在首个 `await tester.pumpAndSettle();`（第 25 行附近）前加：

```dart
    await tester.pumpAndSettle(const Duration(seconds: 3));
```

并把原 `await tester.pumpAndSettle();`（首处）替换为上方这行（让 splash 完成并导航到 /home，已读引导）。

> 确认该文件 `SharedPreferences.setMockInitialValues` 已设 `seenOnboarding: true`（第 11 行确为 true），故 splash 走完后停在 /home，再 `go('/chat')` 即可。

- [ ] **Step 6: Run chat_route_test.dart to verify it passes**

Run: `flutter test test/core/router/chat_route_test.dart`
Expected: PASS。

- [ ] **Step 7: Commit**

```bash
git add lib/core/router/app_router.dart test/core/router/splash_redirect_test.dart test/core/router/chat_route_test.dart
git commit -m "feat(splash): 接入 /splash 路由 + initialLocation + redirect 豁免"
```

---

### Task 5: 端到端验证（跑全量测试 + analyzer）

**Files:**
- 无新增/修改（仅运行验证）

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: ALL PASS（含新增 4+4+3+3 测试，及改造的 splash_redirect/chat_route 测试）。

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No issues found。

- [ ] **Step 3: Manual smoke（可选，需真机/模拟器）**

Run: `flutter run`
Expected:
1. 冷启动瞬间为 slate-50 冷白底（无暖白、无默认图标）。
2. 动画页依次：底面 fade+scale → 帆叶生长 → 航向线画出 → 字标入场，~1.8s。
3. 点按任意位置可跳过。
4. 结束整页 fade 出，无缝露出首页（或 onboarding）。
5. 底色全程连续无闪烁。

- [ ] **Step 4: Commit（如有修复）**

```bash
git add -A
git commit -m "test(splash): 端到端验证全绿"
```

---

### Task 6: 原生 splash 改造（Android 冷底色 + 移除默认图标）

**Files:**
- Modify: `android/app/src/main/res/values/colors.xml`
- Modify: `android/app/src/main/res/drawable/launch_background.xml`
- Modify: `android/app/src/main/res/drawable-v21/launch_background.xml`
- Modify: `android/app/src/main/res/values-night/styles.xml`（如需同步 night 底色）

> **测试约束**：原生 XML 无单元测试覆盖。验收靠 Task 5 Step 3 手动 smoke（冷启动底色）。

- [ ] **Step 1: 改 colors.xml — 新增 splash_paper**

Modify `android/app/src/main/res/values/colors.xml` 全文替换为：

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- 原暖白底，保留避免引用断裂，但 launch_background 已改用 splash_paper -->
    <color name="launch_paper">#FBF8F1</color>
    <!-- 冷调底色（= AppColors.paper #F8FAFC），与应用内 splash 动画底色一致 -->
    <color name="splash_paper">#F8FAFC</color>
</resources>
```

- [ ] **Step 2: 改 drawable/launch_background.xml — 改底色 + 移除 bitmap**

Modify `android/app/src/main/res/drawable/launch_background.xml` 全文替换为：

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- SchoNavi 原生 splash：纯冷底色兜底，应用内动画接管全部视觉 -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_paper" />
</layer-list>
```

- [ ] **Step 3: 改 drawable-v21/launch_background.xml — 同上**

Modify `android/app/src/main/res/drawable-v21/launch_background.xml` 全文替换为：

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- SchoNavi 原生 splash：纯冷底色兜底，应用内动画接管全部视觉 -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_paper" />
</layer-list>
```

- [ ] **Step 4: 确认 night styles.xml（如需）**

`android/app/src/main/res/values-night/styles.xml` 当前用 `@drawable/launch_background`（已改），无需额外改动——night 也会用 `splash_paper` 冷白底。App `themeMode: ThemeMode.light` 不启用 dark，但 XML 改造已对 night 自动生效。**无需修改此文件**。

- [ ] **Step 5: 验证构建**

Run: `flutter build apk --debug`（或 `flutter run`）
Expected: 成功，无 Android 资源编译错误。

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/res/values/colors.xml android/app/src/main/res/drawable/launch_background.xml android/app/src/main/res/drawable-v21/launch_background.xml
git commit -m "feat(splash): 原生 splash 冷底色 + 移除默认图标"
```

---

## Self-Review

**1. Spec coverage（逐条对照 spec §3-§8）：**
- §3.1 ① SplashLogoPainter → Task 1 ✓
- §3.1 ② SplashController → Task 2 ✓
- §3.1 ③ SplashPage → Task 3 ✓
- §3.1 ④ 原生层改造 → Task 6 ✓
- §3.2 入口衔接（/splash initialLocation + go('/home')）→ Task 4 ✓
- §3.3 防回环（redirect splash 豁免）→ Task 4 ✓
- §4.1-4.2 时长 1.8s + 三段 Interval → Task 1 (painter) + Task 3 (字标 0.75-1.0) ✓
- §4.3 帆叶 PathMetric.extractPath → Task 1 ✓
- §4.4 布局 CoolScaffoldBackground + logo 72 + 字标 headlineMedium → Task 3 ✓
- §4.5 跳过行为 → Task 3 `_skip()` ✓
- §4.6 fade-out 200ms + go('/home') → Task 3 `_onFadeOutEnd` ✓
- §5.2 原生 XML 改造（colors + 两份 launch_background）→ Task 6 ✓
- §6 测试策略（painter 单测 + controller 单测 + page widget 测 + 路由测）→ Task 1/2/3/4 ✓
- §7 影响范围（新增 3 文件 + 改 router + 改 2 个 router 测试 + 改 3 个原生 XML）→ 全覆盖 ✓

**2. Placeholder scan：** 无 TBD/TODO/"add error handling" 占位。每步含完整代码或确切命令。Task 6 Step 4 已明确"无需修改"并给出原因。

**3. Type consistency：**
- `SplashState.progress` (double) / `isCompleted` (bool) — Task 2 定义，Task 3 `ref.watch` 读取 `state.progress`/`state.isCompleted` ✓
- `SplashLogoPainter({required this.progress})` — Task 1 定义，Task 3 `SplashLogoPainter(progress: state.progress)` ✓
- `splashControllerProvider` — Task 2 定义，Task 3 `ref.watch/read(...notifier)` ✓
- `clampInterval(t, a, b)` — Task 1 定义，Task 3 复用（同文件 import）✓
- `setProgress`/`complete`/`skip`/`markNavigated` — Task 2 定义，Task 3 调用一致 ✓
- `routerProvider` — 已存在于 `app_router.dart`，Task 3/4 调用 ✓

**4. 一致性修正（已内联）：**
- Task 2 设计取舍说明：Notifier 无 vsync，Ticker 由页面提供，避免 controller 测试需 PumpWidget。
- Task 3 Step 1 修正为组件级测试，导航端到端验移至 Task 4 的 splash_redirect_test。
- Task 4 Step 5/6 处理 chat_route_test.dart 受 initialLocation 改动影响。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-27-schonavi-splash-animation.md`. Two execution options:

**1. Subagent-Driven (recommended)** — 每个 Task 派新 subagent，Task 间 review，快速迭代。

**2. Inline Execution** — 本会话内用 executing-plans 批量执行，带 checkpoint。

**Which approach?**
