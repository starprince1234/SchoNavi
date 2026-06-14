# 首页头部重构 + 动态副标题设计

## Context

第三迭代 rc0 聚焦 UI 改进。首页（`lib/features/home/pages/home_page.dart`）头部当前把三个元素挤进同一行 `Row`：

- 左侧 120dp：`SlidingPillSwitch`（导师/竞赛）左对齐
- 中间 `Expanded`：`SchoNavi` 字标（`FittedBox` 缩放）
- 右侧 120dp：菜单按钮

问题：切换胶囊偏小且偏居一隅、与品牌字标互相争夺视觉重心、字标被两侧固定列挤压。模式切换是本页最高频操作，理应是视觉焦点。

副标题当前为单句静态文案（`_TabConfig.title`，如「用自然语言找到适合你的导师」），缺乏人情味与动态感。

## Goals

1. 重排头部为垂直 Hero 结构：品牌字标做大居中、切换器居中放大成为焦点、副标题置于切换器下方且随模式变化。
2. 副标题改为多句温和文案轮播，带动画切换效果。
3. 动画效果用**策略模式**实现三种（淡入上滑 / 纯淡入淡出 / 打字机），默认展示打字机，后期可一行切换。

## Non-Goals

- 不改动 Bento 示例网格、输入框、快捷标签区域的结构与行为。
- 不改动右边缘滑动开抽屉逻辑。
- 测试不在本次范围内（按用户指示）。

## Design

### 1. 头部布局（`home_page.dart`）

拆掉三栏 `Row`，改为垂直结构（仍包裹在 `AnimatedEntrance(index: 0)` 内）：

```
顶栏（Row, 右对齐）：          ☰  _HomeMenuButton
品牌字标（居中）：         SchoNavi   coral / w800，FittedBox 防溢出
切换器（居中）：        ┌导师┬竞赛┐   SlidingPillSwitch，约 200dp 宽
副标题（居中）：      〔动态轮播文案〕  RotatingSubtitle
```

- 顶栏：`Align(alignment: centerRight, child: _HomeMenuButton())`，保持 44×44 点击目标。
- 品牌字标：居中，沿用 `headlineSmall`/`headlineMedium` 量级（可适度放大），`AppColors.coral`、`FontWeight.w800`，外层 `FittedBox(fit: BoxFit.scaleDown)` 防小屏溢出。
- 切换器：`SlidingPillSwitch` 组件 API 不变，仅改放置——用居中的 `SizedBox(width: ~200)` 包裹（替代原左对齐的 `SizedBox(width:120)`）。
- 各元素间垂直间距用 `SizedBox` 调和（字标↔切换器、切换器↔副标题）。

### 2. 动态副标题组件（新文件 `lib/shared/widgets/rotating_subtitle.dart`）

#### 2.1 RotatingSubtitle（StatefulWidget）

职责：持有一个 `Timer`，在 `phrases` 列表间循环推进索引；把「当前句的动画呈现」委托给注入的策略。

- 入参：`List<String> phrases`、`SubtitleAnimationStrategy strategy`、`TextStyle? style`。
- 当 `phrases` 变化（模式切换）时，`didUpdateWidget` 重置索引到 0 并重启计时器。
- 计时器周期 = `strategy.holdDuration`，每次触发推进到下一句（环形）。
- 无障碍：读取 `MediaQuery.of(context).disableAnimations`，为 true 时停用计时器与动画，静态显示 `phrases.first`。
- `dispose` 中取消计时器。

#### 2.2 策略接口

打字机与淡入淡出机制根本不同（前者逐字呈现单句、后者在两句间过渡），无法统一成单纯的 `AnimatedSwitcher.transitionBuilder`，因此让**策略自身负责整段呈现**：

```dart
abstract interface class SubtitleAnimationStrategy {
  /// 构建展示 [text] 的动画 widget；当 text 变化时，策略决定如何过渡。
  Widget build(BuildContext context, String text, TextStyle? style);

  /// 当前句停留时长（计时器周期）。
  Duration get holdDuration;
}
```

#### 2.3 三个实现

- `FadeSlideStrategy`：`AnimatedSwitcher`，`transitionBuilder` = FadeTransition + SlideTransition（旧句上滑淡出、新句自下方升入）。`holdDuration ≈ 3s`。子节点以 `text` 为 `Key` 触发切换。
- `CrossfadeStrategy`：`AnimatedSwitcher` 仅 `FadeTransition`。`holdDuration ≈ 3s`。
- `TypewriterStrategy`：返回内部有状态的 `_TypewriterText(text)`，在 `text` 变化时用自身 `AnimationController`/计时器逐字敲出（按字符数推进 `substring`），打完保持；`holdDuration` 需 > 打字时长（如打字 ~每字 90ms + 停留约 1.8s，整体取一个安全周期，如 `text.length * 90ms + 2s`，可在策略内按句长动态计算或用固定较大值）。

#### 2.4 默认策略

在 `home_page.dart` 顶部一处常量指定，便于后期调研后替换：

```dart
const SubtitleAnimationStrategy _kSubtitleStrategy = TypewriterStrategy();
```

### 3. 文案池（`_TabConfig`）

`_TabConfig.title`（`String`）→ `taglines`（`List<String>`）。

- 导师（~4 句，温和助手口吻）：
  - 说说你想研究的方向，我帮你找到合适的导师
  - 想做哪个方向的研究？我来帮你找导师
  - 不知道选谁？告诉我你的兴趣就好
  - 地区、方向、阶段，想到什么都可以说
- 竞赛（~4 句，与导师一一对应的语气）：
  - 说说你的兴趣，我帮你找到适合的竞赛
  - 想参加什么样的比赛？我来帮你找
  - 还在纠结报哪个？告诉我你擅长什么
  - 时间、方向、组队，想到什么都可以说

`_currentConfig.taglines` 传给 `RotatingSubtitle`。

## Risks & Mitigations

| 风险 | 缓解 |
| --- | --- |
| 字标放大后小屏溢出 | `FittedBox(scaleDown)` 包裹 |
| 无限计时器/动画影响测试 `pumpAndSettle` | 本次测试不在范围内；组件在 reduce-motion 下静态显示首句，留有可测路径 |
| 打字机 `holdDuration` 短于打字时长导致截断 | 周期按句长动态计算或取足够大固定值 |
| 切换模式时旧轮播残留 | `didUpdateWidget` 重置索引并重启计时器 |

## Rollback

头部布局与副标题改动集中在 `home_page.dart` 与新文件 `rotating_subtitle.dart`；回滚即还原 `home_page.dart` 头部 `Row` 结构、恢复 `_TabConfig.title`、删除新文件。`SlidingPillSwitch` 组件本身不改，无连带影响。
