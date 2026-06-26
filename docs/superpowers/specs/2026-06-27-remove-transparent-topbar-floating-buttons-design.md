# 移除透明顶栏 — 悬浮按钮重构设计

**日期**：2026-06-27
**分支**：iter3rc2
**范围**：首页（`HomePage`）与对话页（`ChatPage`）

## 背景与动机

当前首页与对话页顶部都有一个与背景同色的"透明栏"：

- 首页 [home_page.dart:354-378](lib/features/home/pages/home_page.dart#L354-L378) 是手写的 44px `Row`，背景透出 `CoolScaffoldBackground`。
- 对话页 [chat_page.dart:126-144](lib/features/chat/pages/chat_page.dart#L126-L144) 是 `backgroundColor: Colors.transparent` 的真 `AppBar`，含标题"找导师/继续追问"与右上"重新生成"按钮。

这是反模式：栏体在视觉上"消失"了，但其高度仍占据顶部空间并压在内容之上——既无视觉锚点，又占用屏幕，还遮挡对话流的首条消息。把"新对话""菜单""重新生成"这种**独立操作**挂在一个看不见的栏里，既不直观也违背"顶部留给内容"的原则。

## 目标

移除首页与对话页的透明顶栏，将顶部操作按钮重构为**独立的悬浮圆形玻璃按钮**，置于左上/右上 SafeArea 内，消息流顶部留出避让空间。对齐 ChatGPT App 的版式语言。

## 非目标

- 不改动 `AppMenuDrawer`、`CoolScaffoldBackground`、`RightEdgeOpenDrawer`（边缘滑动）、`ChatInputBar`、消息流逻辑、provider 状态机。
- 不改动其他页面的 `SchoNaviAppBar`（如设置页、历史页等仍各自使用其 `AppBar`）。
- 不为对话页补回标题文字——遵循 YAGNI，标题不再显示。

## 设计决策

| 决策点 | 选择 | 理由 |
|---|---|---|
| 按钮位置 | 左上 + 右上对称悬浮 | ChatGPT App 版式；左上承接"新会话/返回"习惯 |
| 落地态左上 | 留空（不渲染按钮） | 落地态无"新对话"语义；保持简洁，对称仅在对话态出现 |
| 实现路线 | 路线 A：`Stack` + `Positioned` 悬浮按钮 | 栏彻底消失、按钮独立可点、不依赖 `AppBar` |
| 按钮组件 | 自绘圆形玻璃，复用 `GlassSurface` | 与 `BentoTile`/输入栏视觉同源；不用 FAB（阴影+accent 色与冷调玻璃冲突） |
| 范围 | 首页 + 对话页都改 | 一致性 |
| 对话页左上动作 | `context.go('/')` 回首页 | 首页本身即新对话入口，符合既有"新对话就是新对话页"注释语义 |
| 对话页标题 | 移除，不再显示 | 顶部留给内容；硬塞标题破坏悬浮布局 |

## 架构

### 新建组件 `FloatingTopButton`

**文件**：[lib/shared/widgets/floating_top_button.dart](lib/shared/widgets/floating_top_button.dart)

圆形玻璃悬浮按钮，供首页与对话页共用，保证两处视觉一致。

```dart
/// 圆形玻璃悬浮按钮：复用于首页与对话页的左上/右上操作位。
///
/// 视觉：GlassSurface 圆形底 + 居中 Icon，直径 44，符合 Material 最小触控。
/// 与 CoolScaffoldBackground 叠加时呈半透明毛玻璃，避免实体栏遮挡内容。
/// onPressed 为 null 时进入 disabled 态：icon 变灰、无 ripple。
class FloatingTopButton extends StatelessWidget {
  const FloatingTopButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed; // null = disabled

  bool get _disabled => onPressed == null;

  @override
  Widget build(BuildContext context) {
    final iconColor = _disabled ? AppColors.inkSoft : AppColors.ink;
    return Tooltip(
      message: tooltip,
      child: GlassSurface(
        frosted: true,
        radius: 22, // 直径 44 / 2
        padding: EdgeInsets.zero,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _disabled
                ? null
                : () {
                    Haptics.light();
                    onPressed!();
                  },
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 22, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
```

**要点**：
- 直径 44 = Material 最小触控；`CircleBorder` 让 ripple 呈圆形。
- 复用 `GlassSurface` 保持视觉语言统一。shadow 沿用 `GlassSurface` 默认值 `AppColors.shadowCool`，让悬浮按钮在渐变底上略有层次。
- disabled 态：`onPressed: null` → icon 用 `AppColors.inkSoft`，`InkWell.onTap` 为 null。
- `Haptics.light()` 内置，与现有 `_HomeMenuButton` 行为一致。

### 首页布局改造

**移除**：[home_page.dart:354-378](lib/features/home/pages/home_page.dart#L354-L378) 的 44px 手写顶栏 `Row`，以及私有类 `_HomeMenuButton`（[home_page.dart:684-702](lib/features/home/pages/home_page.dart#L684-L702)）。

**新 `Stack` 结构**：

```
Stack
├─ Positioned.fill  CoolScaffoldBackground          (底层，不动)
├─ SafeArea > Column(landing | conversation)        (内容层，不动逻辑)
│   └─ Expanded
│       ├─ 落地态: _buildLandingContent
│       └─ 对话态: _buildConversationContent
│           └─ ListView padding.top = 56            (★避让悬浮按钮)
│   └─ _buildBottomInput
├─ Positioned  top:8 left:12  [新对话|空]           (★新增层)
└─ Positioned  top:8 right:12  [菜单]               (★新增层)
```

**两个悬浮按钮**：
- **右上**：始终 `FloatingTopButton(Icons.menu_outlined, '菜单')` → `Scaffold.of(context).openEndDrawer()`。
- **左上**：`if (_inConversation)` 渲染 `FloatingTopButton(Icons.edit_square, '新对话')` → `_startNewConversation()`；落地态不放进 `Positioned`（左上完全留空）。

**避让 padding**：
- 落地态：`_buildLandingContent` 顶部 padding 不变（落地态 logo 在屏幕上部 1/3，悬浮按钮压在 logo 上方空白处，不冲突）。
- 对话态：`_buildConversationContent` 里 `ListView` 的 `padding` 由 `symmetric(horizontal: 20, vertical: 12)` 改为 `EdgeInsets.fromLTRB(20, 56, 20, 12)`（顶部 56 = 按钮 44 + 上下余量 12）。
- `RightEdgeOpenDrawer` 的 `top` 由 `0` 改为 `56`，避免和右上菜单按钮触控区重叠（边缘滑动从按钮下方开始）。`bottom: 120` 不变。

### 对话页布局改造

**移除**：[chat_page.dart:126-144](lib/features/chat/pages/chat_page.dart#L126-L144) 的透明 `AppBar`（标题"找导师/继续追问" + 右上"重新生成"）。

**新 `Stack` 结构**：

```
Stack
├─ Positioned.fill  CoolScaffoldBackground
├─ SafeArea > Column
│   └─ Expanded
│       └─ ListView  padding = EdgeInsets.fromLTRB(20, 56, 20, 12)  ★避让
│       └─ ChatQuickActions
│       └─ ChatInputBar
├─ Positioned  top:8 left:12   [新对话]
└─ Positioned  top:8 right:12  [重新生成]
```

**两个悬浮按钮**：
- **左上**：`FloatingTopButton(Icons.edit_square, '新对话')` → `context.go('/')`（回首页 = 开新会话）。
- **右上**：`FloatingTopButton(Icons.refresh, '重新生成')` → `ref.read(_provider.notifier).regenerate()`。沿用 `state.canRegenerate` 禁用：`canRegenerate` 为 false 时 `onPressed: null`，按钮置灰。

**标题处理**：移除 `AppBar` 后，"找导师/继续追问"不再显示。顶部完全留给消息流。

## 数据流

无数据流变化。`FloatingTopButton` 是纯展示组件，回调由调用方注入：

- 首页左上"新对话" → `_startNewConversation()`（已存在，invalidate provider + 重置 `_inConversation`）。
- 首页右上"菜单" → `Scaffold.openEndDrawer()`（已存在）。
- 对话页左上"新对话" → `context.go('/')`（go_router 已注入）。
- 对话页右上"重新生成" → `chatProvider.notifier.regenerate()`（已存在）。

## 错误处理

无新错误路径。`FloatingTopButton` 的 disabled 态用 `onPressed: null` 表达，不抛异常。

## 测试

### 新增

**`test/shared/widgets/floating_top_button_test.dart`**：
- 渲染：给定 icon/tooltip，显示正确 icon，`Tooltip` message 正确。
- 点击：`onPressed` 被调用。
- disabled 态：`onPressed: null` 时 icon 颜色为 `inkSoft`，点击不触发回调。

**首页测试**（`test/features/home/pages/home_page_test.dart`，扩展现有）：
- 落地态：左上无悬浮按钮（断言找不到 `Icons.edit_square`），右上存在菜单按钮。
- 对话态：左上出现"新对话"按钮，点击后 `_inConversation` 归 false、provider 被 invalidate。
- 对话态 `ListView` 顶部 padding = 56。

**对话页测试**（`test/features/chat/pages/chat_page_test.dart`，扩展现有）：
- 不再渲染 `AppBar`（断言 `find.byType(AppBar)` 为 0；若现有测试断言标题文字"找导师""继续追问"，需同步改为断言按钮存在性——见回归清单）。
- 右上"重新生成"按钮存在；`canRegenerate=false` 时按钮 disabled。
- 左上"新对话"点击 → 路由跳转到 `/`。

### 回归清单（手动或既有测试覆盖）

- `CoolScaffoldBackground` 渐变不受影响。
- `AppMenuDrawer` 从右侧滑出正常（`openEndDrawer` 调用点不变）。
- `RightEdgeOpenDrawer` 边缘滑动区域 `top` 从 0 改为 56 后仍能触发开抽屉。
- 对话页 `regenerate`、`stop`、消息流滚动到底——逻辑未动，应全绿。
- 键盘弹起 `resizeToAvoidBottomInset` 行为不变。

### 现有测试需同步调整

首页/对话页若有断言 `AppBar` 标题文字（"找导师""继续追问"）或 `find.byType(AppBar)` 的测试，会失败——需改为断言悬浮按钮存在性。具体清单在实现阶段对照测试输出确定。

## 验证

实现完成后运行：

```bash
flutter test
flutter analyze
```

预期：全绿、无新 warning。手动在 Windows 桌面 / Android 模拟器上确认：
- 首页落地态：左上空、右上菜单按钮，logo 与 prompt 网格不被遮挡。
- 首页对话态：左上"新对话"、右上"菜单"，第一条消息不被按钮遮挡。
- 对话页：左上"新对话"、右上"重新生成"（busy 时置灰），消息流顶部有避让。
- 右滑边缘可开抽屉。
