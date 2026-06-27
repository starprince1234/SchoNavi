# ThinkingIndicator 三点跳跃 设计

- 日期：2026-06-27
- 范围：`lib/shared/widgets/thinking_indicator.dart` + 对应测试
- 目标：把「正在思考…」尾部的省略号改为三个独立圆点，并赋予错峰上下跳跃动效；其余视觉（图标扫光、文字渐变填充、文字横向亮纹）保持不变。

## 背景

当前 `ThinkingIndicator` 文案为单个字符串 `'正在思考…'`，结尾的 `…` 是 U+2026 单字形，无法让其中三个点独立动。整个文案被 `ShaderMask(brandGradient, srcIn)` 染品牌渐变，外层 `CustomPaint(foregroundPainter: _TextShimmerPainter)` 叠一条横向掠过的亮带。类注释自称「不脉动（无 scale/opacity 动画），只有滑光匀速扫过」。

用户希望尾三点有跳跃感，并选择「保留 shimmer，只改点」：shimmer 继续只覆盖「正在思考」四字，三个点用品牌渐变填充并自带跳跃。

## 方案

### 驱动：复用现有 2s `AnimationController`

不新增控制器，沿用 `SingleTickerProviderStateMixin` 与 `_controller`（`repeat()`，2s/圈）。所有动效共享同一时钟：

- 图标圆周扫光：`progress = value * 2π`
- 文字横向亮纹：`progress = value`
- 三点跳跃：从 `value` 派生相位

视觉同呼吸、改动最小、不引入第二个 ticker。

### 布局

外层 `Row` 不变，仍为：图标 → `SizedBox(width:8)` → 文案块。文案块改为：

```text
Row(mainAxisSize: min, children: [
  // 「正在思考」四字：去掉「…」
  AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => CustomPaint(
      foregroundPainter: _TextShimmerPainter(progress: _controller.value),
      child: child,
    ),
    child: ShaderMask(
      shaderCallback: AppColors.brandGradient.createShader,
      blendMode: BlendMode.srcIn,
      child: const Text('正在思考'),
    ),
  ),
  const SizedBox(width: 3),
  ...三点,
])
```

### 三圆点

每个圆点：

- `SizedBox(width:5, height:5)`
- `BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle)`
- 外包 `Transform.translate(offset: Offset(0, _dotOffset(i)))`
- `ValueKey<int>(i)`（便于测试定位）

圆点间 `SizedBox(width:3)`。

### 跳跃函数 `_dotOffset(int i)`

`i ∈ {0,1,2}`，由 `_controller.value`（记为 `v`）派生：

```dart
double _dotOffset(int i) {
  // 每秒约 1 跳（2s controller 内跑 2 个周期），错峰 0.2 形成波浪。
  final t = (v * 2 + i * 0.2) % 1.0;
  if (t > 0.6) return 0.0;       // 40% 静止
  final u = t / 0.6;              // 0..1
  return -math.sin(u * math.pi) * 5; // 0 → -5px(顶) → 0
}
```

- 仅 `Transform.translate`（不改布局、无 scale/opacity），符合「跳跃」语义。
- 三点错峰 0.2 → 波浪式连续跳跃。
- 幅度 5px，与圆点尺寸（5px）匹配，可见但不夸张。

### 文档同步

类注释当前「不脉动（无 scale/opacity 动画），只有滑光匀速扫过」加跳跃后不再为真，更新为：

> 图标匀速扫光；文案渐变填充 + 横向亮纹；尾三点错峰跳跃（波浪式）。

## 测试（TDD，先红后绿）

文件：`test/shared/widgets/thinking_indicator_test.dart`

1. **基本渲染**：`find.text('正在思考')`（删去 `…`）；`find.byType(SvgPicture)` 仍 `findsOneWidget`；无 `CircularProgressIndicator`。
2. **文字渐变 + shimmer 不变**：原第 2 个测试——ShaderMask `blendMode==srcIn`、文字上方存在 `CustomPaint.foregroundPainter != null`。文案定位改为 `'正在思考'`。
3. **三点存在且品牌渐变圆形**：`find.byKey(const ValueKey<int>(0/1/2))` 各 `findsOneWidget`；其 `DecoratedBox` 的 `BoxDecoration.shape==BoxShape.circle` 且 `gradient==AppColors.brandGradient`。
4. **真在跳**：起始 `v=0` 时三点 `dy==0`；`pump(Duration(milliseconds:300))` 后 `v≈0.15`，此时 `i=0` 的 `t=0.3`（活跃段），其 `Transform.translate.offset.dy` 应为非零（约 -5）。断言该帧 `dy != 0`，证明跳跃真在发生。
5. **dispose 无异常**：原第 3 个测试保留——repeat 不阻塞 pump，重挂载后 `takeException()` isNull。

## 不做

- 不新增 `AnimationController` / 不切 `TickerProviderStateMixin`。
- 不改图标扫光、不改 `_TextShimmerPainter`、不改 `AppColors`。
- 不改 `ThinkingIndicator` 对外 API（`const ThinkingIndicator({super.key})`）。
- 不加 scale/opacity 动画（仅 translate）。
