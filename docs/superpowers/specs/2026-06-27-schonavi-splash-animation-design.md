# SchoNavi 开屏动画设计

**日期**：2026-06-27
**状态**：待实现
**类型**：功能设计（视觉 + 工程）

## 1. 背景与目标

SchoNavi 当前冷启动体验存在割裂：`main.dart` 直接 `runApp(SchoNaviApp)` 进路由，无任何开屏；而 Android 原生层 `launch_background.xml` 使用暖白底色 `#FBF8F1` + 默认 Flutter `ic_launcher` 图标，与 App 的冷调玻璃拟态（Cool Glassmorphism）设计系统冲突。用户冷启动会先看到暖白屏与默认图标闪烁，再突切到首页，体验割裂。

**目标**：为 SchoNavi 添加一个好看、简洁的开屏动画——
- 原生层提供 instant 冷底色兜底，消除暖白闪烁；
- 应用内播放 ~1.8s 的品牌绘制叙事动画；
- 结束整页 fade 出，无缝交给 go_router 的 onboarding 重定向逻辑。

## 2. 关键决策（用户已确认）

| 决策点 | 选择 |
|---|---|
| 开屏类型 | 原生 splash 兜底 + 应用内动画 |
| 动画方案 | 方案 A：Logo 三段绘制 + 字标入场 |
| 结尾过渡 | 整页 fade 出 |
| 时长与跳过 | 1.8s + 可点按跳过 |
| 显示时机 | 每次冷启动都播 |

## 3. 架构与衔接

### 3.1 组件边界（4 个独立单元）

**① `SplashLogoPainter`** — `lib/shared/widgets/splash_logo_painter.dart`

参数化品牌标 `CustomPainter`，接受 `double progress`（0.0→1.0）控制三段绘制。提取自现有 `SchoNaviLogo._MarkPainter` 的绘制逻辑，改为 progress 驱动：底面 fade+scale、帆叶沿贝塞尔 trim 生长、航向线横向画出。纯绘制、无状态、可独立单测（给定 progress 断言 canvas 调用）。

**② `SplashController`** — `lib/features/splash/splash_controller.dart`

Riverpod `Notifier<double>`，持有 progress（0.0→1.0）与 `isCompleted`。
- `start()` 启动一个 1.8s 的 `Ticker` 驱动 progress 上升；
- `skip()` 立即跳到 1.0 并触发收尾；
- progress 到 1.0 后置 `isCompleted = true`，UI 层据此触发 fade-out。

可独立单测（pump 验证 progress 上升、skip 行为）。

**③ `SplashPage`** — `lib/features/splash/pages/splash_page.dart`

`ConsumerStatefulWidget`，监听 `SplashController`。用 `AnimatedBuilder` + `CustomPaint` 渲染 `SplashLogoPainter(progress)` + 字标 stagger。点按区域 `onTap` → `controller.skip()`。`isCompleted` 时外层 `AnimatedOpacity` fade-out，结束后用 `ref.read(routerProvider).go('/home')` 交还路由。

**④ 原生层改造** — `android/app/src/main/res/`

`colors.xml` 新增冷底色、`launch_background.xml` 改底色并移除默认图标。纯 XML，零新增依赖。

### 3.2 入口衔接

`main.dart` 不变。路由层衔接点：

- 在 `routerProvider` 中新增 `/splash` 路由，并将 `initialLocation` 从 `/home` 改为 `/splash`。
- `SplashPage` 动画结束（fade-out 完成后）调用 `ref.read(routerProvider).go('/home')`。
- `redirect` 逻辑需小幅修改（见 3.3 防回环）：为 `/splash` 加豁免分支。豁免后，`go('/home')` 触发 redirect 读 `OnboardingPage.seenKey`，未看 onboarding 则自动跳 `/onboarding`，看过则留 `/home`。
- **splash 不感知 onboarding 逻辑，职责纯净。**

### 3.3 防回环

`/splash` 路由需在 `redirect` 中豁免：在 redirect 开头增加 `if (state.matchedLocation == '/splash') return null;`，使其不参与 onboarding 重定向。否则未看 onboarding 的用户在 `/splash` 时会满足 `!seen && !atOnboarding`（`/splash` != `/onboarding`）而被直接重定向到 `/onboarding`，splash 动画无法播放。其余 onboarding 分支逻辑保持不变。

## 4. 动画时间线与视觉

### 4.1 时长

总时长 1.8s，progress 0.0→1.0 线性映射时间，各元素用各自的 `Interval` 错峰。

### 4.2 元素时间线

| progress 区间 | 元素 | 动画 | 缓动 |
|---|---|---|---|
| 0.00–0.30 | 圆角方底（slate→indigo 渐变） | opacity 0→1 + scale 0.7→1.0 | easeOut |
| 0.20–0.70 | cyan 帆叶 | 沿贝塞尔曲线绘制生长（trim 0→1），起点固定左下、终点随进度沿曲线推进 | easeInOut |
| 0.60–0.90 | 白航向线 | 从左到右横向画出（line trim 0→1，圆头描边） | easeOut |
| 0.75–1.00 | 「SchoNavi」字标 | opacity 0→1 + translate y +12→0，brandGradient 渐变 | easeOut |

### 4.3 帆叶绘制实现（核心技巧）

帆叶是一条 cubic 贝塞尔闭合路径。`SplashLogoPainter` 用 `PathMetric` 测量全长，按 `progress` 取 `extractPath` 子路径，从左下起点向右上扬起方向生长——视觉上是"帆从底升起、向航向扬起"，呼应导航/成长语义。

### 4.4 布局

- 整页 `CoolScaffoldBackground`（复用现有冷渐变底，保证 fade 出时露出的首页底色一致、无闪烁）。
- 居中：logo（size ~72）+ 下方字标（headlineMedium，与首页 `SchoNaviLogo` 字标样式一致）。
- 无额外文字、无 loading spinner——动画本身就是加载态。

### 4.5 跳过行为

点按任意位置 → `skip()`，progress 直接置 1.0、字标已完成态、立即触发 fade-out（fade-out 本身 ~200ms）。不硬切，走完收尾。

### 4.6 fade-out

`isCompleted` 为真后，外层 `AnimatedOpacity(opacity: 0, duration: 200ms, curve: easeOut)`，动画结束后 `go('/home')`。

## 5. 原生 splash 改造细节

### 5.1 问题

现有 `launch_background.xml` 用暖白 `#FBF8F1` + 默认 Flutter `ic_launcher`，与冷调设计系统冲突。

### 5.2 改造（纯 XML，零新增依赖）

1. **`values/colors.xml`**：
   - 新增 `<color name="splash_paper">#F8FAFC</color>`（= `AppColors.paper`，slate-50 冷白）。
   - 保留旧 `launch_paper` 暖白色不删（避免引用断裂），但 `launch_background.xml` 改用新色。

2. **`drawable/launch_background.xml`** + **`drawable-v21/launch_background.xml`**：
   - 底色 item 改为 `@color/splash_paper`。
   - 移除 `<bitmap>` item（默认 Flutter 图标）——纯冷底色，让 Flutter 动画页接管全部视觉。

3. **`values-night/styles.xml`** 检查：App 当前 `themeMode: ThemeMode.light`，dark 不启用，但为完整性确认 night styles 同步用 `splash_paper`（或新增 `splash_paper_dark = #0B1120`）。

### 5.3 结果

冷启动瞬间显示纯 slate-50 冷白底（与首页 `CoolScaffoldBackground` 顶色一致），无默认图标、无暖白闪烁 → Flutter 引擎就绪后动画页无缝接上 → 整页 fade 出露出首页，底色全程连续。

### 5.4 取舍

不引入 `flutter_native_splash` 包。纯冷底色 + 应用内动画已足够消除割裂感，原生层 logo 非必要，且保持零新增依赖、跨平台一致性更易保证。

## 6. 测试策略

遵循项目强测试约定（参考 `schonavi-dev-conventions`）。

### 6.1 `SplashLogoPainter` 单测

- 给定 `progress = 0`：帆叶、航向线不应被绘制（断言 canvas 调用次数/路径为空）。
- 给定 `progress = 1`：帆叶、航向线完整绘制（路径全长）。
- 给定中间 `progress`：`extractPath` 子路径长度与预期成比例。
- 用 `repaintBoundary` + mock canvas 或 `PathMetric` 长度断言。

### 6.2 `SplashController` 单测

- `start()` 后 pump 0.9s：progress ≈ 0.5，`isCompleted == false`。
- `start()` 后 pump 1.8s：progress == 1.0，`isCompleted == true`。
- `skip()`：progress 立即 == 1.0，`isCompleted == true`。

### 6.3 `SplashPage` widget 测试

- 初始渲染：logo painter 存在，整页 opacity = 1。
- 点按 → 触发 skip → pump → `isCompleted` 为真、整页 opacity 趋向 0。
- fade-out 完成 → 断言 `routerProvider` 被导航到 `/home`（用 fake router 或断言 `go` 调用）。
- 防回环：`/splash` 在 redirect 中豁免。

### 6.4 路由测试

- `initialLocation == '/splash'`。
- `/splash` redirect 返回 null（豁免）。
- 未看 onboarding 时从 splash `go('/home')` → 最终落到 `/onboarding`。

## 7. 影响范围

### 7.1 新增文件

- `lib/shared/widgets/splash_logo_painter.dart`
- `lib/features/splash/splash_controller.dart`
- `lib/features/splash/pages/splash_page.dart`
- 对应 3 个测试文件。

### 7.2 修改文件

- `lib/core/router/app_router.dart`：新增 `/splash` 路由，`initialLocation` 改 `/splash`，redirect 加 splash 豁免。
- `android/app/src/main/res/values/colors.xml`：新增 `splash_paper`。
- `android/app/src/main/res/drawable/launch_background.xml`：改底色、移除 bitmap。
- `android/app/src/main/res/drawable-v21/launch_background.xml`：同上。
- `android/app/src/main/res/values-night/styles.xml`：检查同步（如需）。

### 7.3 不变

- `main.dart`、`app.dart`、onboarding 逻辑、首页、设计 token。
- 零新增 pubspec 依赖。

## 8. 验收标准

1. 冷启动无暖白屏、无默认图标闪烁，瞬间为 slate-50 冷白底。
2. 动画页依次播放：底面 fade+scale → 帆叶沿贝塞尔生长 → 航向线画出 → 字标入场，总时长 ~1.8s。
3. 点按任意位置可跳过，跳过后走完 fade-out 收尾，不硬切。
4. 动画结束整页 fade 出，无缝露出首页（或 onboarding），底色连续无闪烁。
5. 所有新增单测与 widget 测试通过；现有测试不回归。
6. `/splash` 路由豁免 onboarding 重定向，无回环。
