# 移除透明顶栏 — 悬浮按钮重构 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 移除首页与对话页的透明顶栏，将「新对话」「菜单」「重新生成」重构为独立的圆形玻璃悬浮按钮（左上/右上），消息流顶部留出避让空间。

**Architecture:** 新建一个可复用的纯展示组件 `FloatingTopButton`（圆形 `GlassSurface` + `Icon`，支持 disabled 态），首页与对话页各自在其 `Stack` 顶层用 `Positioned` 放置左上/右上按钮，移除原 `AppBar`/手写顶栏 `Row`，消息 `ListView` 顶部 padding 提升到 56 避让按钮。无数据流变化，所有回调复用既有方法。

**Tech Stack:** Flutter 3.x、Riverpod 3.2.1、go_router、项目自有 `GlassSurface`/`AppColors`/`Haptics`。

## Global Constraints

- 视觉语言统一：按钮必须复用 `GlassSurface`（`frosted: true`），与 `BentoTile`/输入栏同源；不用 `FloatingActionButton`。
- 触控尺寸：按钮直径 44（Material 最小触控），`radius: 22`。
- tooltip 文案：「新对话」「菜单」「重新生成」——与现有测试断言一致。
- 避让 padding：对话态 `ListView` 顶部 = 56（按钮 44 + 上下余量 12）。
- 不改动：`AppMenuDrawer`、`CoolScaffoldBackground`、`RightEdgeOpenDrawer`（仅其 `top` 由 0→56）、`ChatInputBar`、provider 状态机、消息流逻辑。
- disabled 态：`onPressed: null` → icon 用 `AppColors.inkSoft`，`InkWell.onTap` 为 null。
- 测试约定：widget 测试用 `MaterialApp`/`MaterialApp.router` 包裹，pumpAndSettle 后断言；Haptics 在测试中需 mock `SystemChannels.platform`（参考 `test/core/haptics/haptics_test.dart`）。
- 频繁提交：每个 Task 结束 commit。

---

## File Structure

| 文件 | 责任 | 操作 |
|---|---|---|
| `lib/shared/widgets/floating_top_button.dart` | 圆形玻璃悬浮按钮组件，支持 disabled | 新建 |
| `test/shared/widgets/floating_top_button_test.dart` | `FloatingTopButton` 单元测试 | 新建 |
| `lib/features/home/pages/home_page.dart` | 首页：移除顶栏 Row，改 Stack+悬浮按钮，调 ListView padding，调 RightEdgeOpenDrawer.top | 修改 |
| `test/features/home/home_page_test.dart` | 首页落地态/对话态悬浮按钮断言 | 修改（新增 + 调整） |
| `test/features/home/home_page_conversation_test.dart` | 对话态既有断言复核（已含「新对话」tooltip） | 修改（仅微调） |
| `lib/features/chat/pages/chat_page.dart` | 对话页：移除 AppBar，改 Stack+悬浮按钮，调 ListView padding | 修改 |
| `test/features/chat/chat_page_test.dart` | 对话页：调整 AppBar/标题相关断言 | 修改 |

---

## Task 1: 新建 FloatingTopButton 组件

**Files:**
- Create: `lib/shared/widgets/floating_top_button.dart`
- Test: `test/shared/widgets/floating_top_button_test.dart`

**Interfaces:**
- Consumes: `lib/shared/widgets/glass_surface.dart`（`GlassSurface({child, frosted, radius, padding, border})`）、`lib/core/theme/app_colors.dart`（`AppColors.ink`、`AppColors.inkSoft`）、`lib/core/haptics/haptics.dart`（`Haptics.light()`）。
- Produces: `FloatingTopButton({required IconData icon, required String tooltip, required VoidCallback? onPressed})` —— 后续 Task 2/3 消费此构造。

- [ ] **Step 1: 写失败测试**

创建 `test/shared/widgets/floating_top_button_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/theme/app_colors.dart';
import 'package:scho_navi/shared/widgets/floating_top_button.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('渲染给定 icon 并暴露 tooltip', (tester) async {
    await tester.pumpWidget(
      _wrap(const FloatingTopButton(icon: Icons.menu_outlined, tooltip: '菜单', onPressed: null)),
    );
    expect(find.byIcon(Icons.menu_outlined), findsOneWidget);
    expect(find.byTooltip('菜单'), findsOneWidget);
  });

  testWidgets('点击触发 onPressed 回调', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _wrap(FloatingTopButton(icon: Icons.edit_square, tooltip: '新对话', onPressed: () => tapped++)),
    );
    await tester.tap(find.byIcon(Icons.edit_square));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('onPressed 为 null 时 disabled：icon 用 inkSoft 且不触发回调', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _wrap(FloatingTopButton(icon: Icons.refresh, tooltip: '重新生成', onPressed: null)),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.refresh));
    expect(icon.color, AppColors.inkSoft);
    // InkWell.onTap 为 null，断言无回调可触发。
    final ink = tester.widget<InkWell>(find.byType(InkWell));
    expect(ink.onTap, isNull);
    expect(tapped, 0);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/shared/widgets/floating_top_button_test.dart`
Expected: FAIL —— `Target of URI doesn't exist: 'package:scho_navi/shared/widgets/floating_top_button.dart'`（组件未创建）。

- [ ] **Step 3: 写最小实现**

创建 `lib/shared/widgets/floating_top_button.dart`：

```dart
import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import 'glass_surface.dart';

/// 圆形玻璃悬浮按钮：复用于首页与对话页的左上/右上操作位。
///
/// 视觉：GlassSurface 圆形底 + 居中 Icon，直径 44，符合 Material 最小触控。
/// 与 CoolScaffoldBackground 叠加时呈半透明毛玻璃，避免实体栏遮挡内容。
/// [onPressed] 为 null 时进入 disabled 态：icon 变灰、无 ripple。
class FloatingTopButton extends StatelessWidget {
  const FloatingTopButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;

  final String tooltip;

  /// null = disabled（icon 灰、无点击）。
  final VoidCallback? onPressed;

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

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/shared/widgets/floating_top_button_test.dart`
Expected: PASS（3 个测试全绿）。

- [ ] **Step 5: 静态检查**

Run: `flutter analyze lib/shared/widgets/floating_top_button.dart test/shared/widgets/floating_top_button_test.dart`
Expected: 无 error/warning。

- [ ] **Step 6: 提交**

```bash
git add lib/shared/widgets/floating_top_button.dart test/shared/widgets/floating_top_button_test.dart
git commit -m "feat(widget): 新建 FloatingTopButton 圆形玻璃悬浮按钮组件"
```

---

## Task 2: 首页移除透明顶栏，改用悬浮按钮

**Files:**
- Modify: `lib/features/home/pages/home_page.dart`（顶栏 Row 在 `build` 的 `Stack` 内约 354-378 行；`_HomeMenuButton` 私有类在 684-702 行；对话态 `ListView` padding 在 `_buildConversationContent` 约 508 行；`RightEdgeOpenDrawer` 的 `top:0` 约 398 行）
- Test: `test/features/home/home_page_test.dart`（新增落地态/对话态悬浮按钮断言）

**Interfaces:**
- Consumes: Task 1 的 `FloatingTopButton`。
- Produces: 首页顶部「新对话」「菜单」两个悬浮按钮，对话态 `ListView` 顶部 padding=56，`RightEdgeOpenDrawer.top=56`。

**关键背景**：首页当前在 `Stack` 内有一个 44px 手写 `Row`（含「新对话」`IconButton` 在对话态、`_HomeMenuButton` 在右上）。`_HomeMenuButton` 私有类在文件末尾。改造后这整个 `Row` 删除，按钮搬到 `Stack` 顶层的两个 `Positioned`。落地态左上不渲染按钮（留空）。

- [ ] **Step 1: 写失败测试（先扩 home_page_test.dart）**

在 `test/features/home/home_page_test.dart` 的 `main()` 内追加（放在文件末尾 `}` 之前）：

```dart
  testWidgets('落地态：左上无新对话按钮，右上存在菜单按钮', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    // 落地态左上无「新对话」悬浮按钮。
    expect(find.byTooltip('新对话'), findsNothing);
    // 右上始终有「菜单」悬浮按钮。
    expect(find.byTooltip('菜单'), findsOneWidget);
    // 不再有 AppBar 实体栏。
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('对话态：左上出现新对话按钮，点击回到落地态', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '我想找医学影像方向的导师');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    // 对话态左上「新对话」出现。
    expect(find.byTooltip('新对话'), findsOneWidget);
    // 点击回到落地态。
    await tester.tap(find.byTooltip('新对话'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('新对话'), findsNothing);
  });
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/features/home/home_page_test.dart`
Expected: FAIL —— 「落地态」测试因当前仍有 `AppBar`? 注意：首页当前**没有** `AppBar`（是手写 `Row`），但 `_HomeMenuButton` 用的是 `IconButton` tooltip '菜单'，所以「菜单」tooltip 应已存在。失败点应在「新对话」断言：落地态 `find.byTooltip('新对话')` 当前实现里 `_inConversation` 为 false 时不渲染该按钮——所以这条可能已通过。真正驱动改造的是「对话态」断言与确认无 `AppBar`。若已有断言通过，仍执行改造使按钮变成 `FloatingTopButton` 视觉。运行后记录实际失败项，继续实现使其全绿。

- [ ] **Step 3: 修改 home_page.dart —— 移除顶栏 Row，改 Stack 顶层悬浮按钮**

定位 `build` 方法内 `Stack` 的 `children`。当前结构（约 344-408 行）：

```dart
          return Stack(
            children: [
              // 冷调渐变底：玻璃面在其上折射出层次。
              const Positioned.fill(child: CoolScaffoldBackground()),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      children: [
                        // Fixed top bar: 对话态左侧是新会话入口，菜单常驻右上。
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: SizedBox(
                            height: 44,
                            width: double.infinity,
                            child: Row(
                              children: [
                                if (_inConversation)
                                  IconButton(
                                    tooltip: '新对话',
                                    icon: const Icon(Icons.edit_square),
                                    onPressed: _startNewConversation,
                                  )
                                else
                                  const SizedBox(width: 12),
                                const Spacer(),
                                const _HomeMenuButton(),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: _inConversation
                              ? _buildConversationContent(textTheme, scheme)
                              : _buildLandingContent(
                                  textTheme,
                                  scheme,
                                  promptsAsync,
                                ),
                        ),
                        _buildBottomInput(scheme),
                      ],
                    ),
                  ),
                ),
              ),
              // Right-edge swipe area. It stops 120 logical pixels above the
              // bottom of the screen so it does not steal horizontal scroll
              // gestures from the tag row.
              Positioned(
                top: 0,
                right: 0,
                bottom: 120,
                child: RightEdgeOpenDrawer(
                  onSwipe: () {
                    Haptics.light();
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
              ),
            ],
          );
```

替换为（移除 `Padding`+`SizedBox`+`Row` 顶栏，把 Column 内只剩 `Expanded` + `_buildBottomInput`；在 `Stack` 顶层加两个 `Positioned` 悬浮按钮；`RightEdgeOpenDrawer.top` 由 0 改 56）：

```dart
          return Stack(
            children: [
              // 冷调渐变底：玻璃面在其上折射出层次。
              const Positioned.fill(child: CoolScaffoldBackground()),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      children: [
                        Expanded(
                          child: _inConversation
                              ? _buildConversationContent(textTheme, scheme)
                              : _buildLandingContent(
                                  textTheme,
                                  scheme,
                                  promptsAsync,
                                ),
                        ),
                        _buildBottomInput(scheme),
                      ],
                    ),
                  ),
                ),
              ),
              // 左上悬浮：仅对话态出现「新对话」；落地态留空。
              if (_inConversation)
                Positioned(
                  top: 8,
                  left: 12,
                  child: FloatingTopButton(
                    icon: Icons.edit_square,
                    tooltip: '新对话',
                    onPressed: _startNewConversation,
                  ),
                ),
              // 右上悬浮：「菜单」常驻。
              Positioned(
                top: 8,
                right: 12,
                child: FloatingTopButton(
                  icon: Icons.menu_outlined,
                  tooltip: '菜单',
                  onPressed: () {
                    Haptics.light();
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
              ),
              // Right-edge swipe area. It stops 120 logical pixels above the
              // bottom of the screen so it does not steal horizontal scroll
              // gestures from the tag row. top:56 避让右上菜单按钮触控区。
              Positioned(
                top: 56,
                right: 0,
                bottom: 120,
                child: RightEdgeOpenDrawer(
                  onSwipe: () {
                    Haptics.light();
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
              ),
            ],
          );
```

- [ ] **Step 4: 删除 `_HomeMenuButton` 私有类**

删除文件末尾的 `_HomeMenuButton` 类（约 684-702 行）：

```dart
class _HomeMenuButton extends StatelessWidget {
  const _HomeMenuButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '菜单',
      icon: const Icon(Icons.menu_outlined),
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      onPressed: () {
        Haptics.light();
        Scaffold.of(context).openEndDrawer();
      },
    );
  }
}
```

- [ ] **Step 5: 调对话态 ListView 顶部 padding**

定位 `_buildConversationContent` 内 `ListView.builder`（约 506-508 行）：

```dart
          child: ListView.builder(
            controller: _conversationScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
```

改为：

```dart
          child: ListView.builder(
            controller: _conversationScrollController,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
```

- [ ] **Step 6: 加 import**

在 `home_page.dart` 顶部 import 区追加：

```dart
import '../../../shared/widgets/floating_top_button.dart';
```

（放在 `app_menu_drawer.dart` import 附近即可，保持字母序。）

- [ ] **Step 7: 运行首页测试，确认通过**

Run: `flutter test test/features/home/home_page_test.dart`
Expected: PASS（含新增 2 个 + 既有全部）。

- [ ] **Step 8: 运行首页对话态测试，确认无回归**

Run: `flutter test test/features/home/home_page_conversation_test.dart`
Expected: PASS。该文件已有 `find.byTooltip('新对话')` 断言（172、250、256 行），改造后 tooltip 仍为「新对话」，应继续通过。若 `right edge swipe opens the end drawer`（home_page_test.dart 242-256 行）因 `top:56` 失败，检查 fling 起点是否在 56 以下；该测试从 `Offset(size.width - 10, 200)` 起手，200 > 56，不受影响。

- [ ] **Step 9: 静态检查**

Run: `flutter analyze lib/features/home/pages/home_page.dart`
Expected: 无 error/warning（注意删除 `_HomeMenuButton` 后不应有未使用 import；`Haptics` 仍被新 `onPressed` 使用，保留）。

- [ ] **Step 10: 提交**

```bash
git add lib/features/home/pages/home_page.dart test/features/home/home_page_test.dart
git commit -m "refactor(home): 移除透明顶栏改用悬浮按钮，消息流顶部留避让"
```

---

## Task 3: 对话页移除透明 AppBar，改用悬浮按钮

**Files:**
- Modify: `lib/features/chat/pages/chat_page.dart`（`AppBar` 在 `build` 内约 126-144 行；`ListView` padding 约 154-159 行；新增左上/右上悬浮按钮层）
- Test: `test/features/chat/chat_page_test.dart`（调整 AppBar/标题断言）

**Interfaces:**
- Consumes: Task 1 的 `FloatingTopButton`；既有 `chatProvider`、`state.canRegenerate`、go_router 的 `context.go`。
- Produces: 对话页左上「新对话」→ `context.go('/')`；右上「重新生成」→ `regenerate()`。

**关键背景**：[chat_page.dart:126-144](lib/features/chat/pages/chat_page.dart#L126-L144) 当前是透明 `AppBar`，含 `title`（`isNewSession ? '找导师' : '继续追问'`）和右上「重新生成」`IconButton`（`state.canRegenerate` 控制启用）。移除后标题不再显示，按钮搬入 `Stack`。注意 chat 页消息气泡内**也有**「重新生成」按钮（tooltip 同名），故顶层「重新生成」断言需用 `find.byTooltip('重新生成')` 配合祖先限定避免误判——但本 Task 顶层按钮放在 `Column` 之外的 `Stack` 顶层 `Positioned`，气泡在 `ListView` 内，二者无祖先关系；测试用 `find.byTooltip` + `findsWidgets` 即可。

- [ ] **Step 1: 写失败测试（先调整 chat_page_test.dart）**

定位 `test/features/chat/chat_page_test.dart`。

(a) 第一个测试「挂载后显示标题与快捷操作」（92-100 行）当前断言 `expect(find.text('继续追问'), findsWidgets)`——标题移除后会失败。改为断言悬浮按钮存在：

```dart
  testWidgets('挂载后显示悬浮按钮与快捷操作', (tester) async {
    await tester.pumpWidget(
      _wrap(_StreamChatRepo(() => Stream.fromIterable(const ['x']))),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('新对话'), findsOneWidget);
    expect(find.byTooltip('重新生成'), findsWidgets);
    expect(find.text('换一批'), findsOneWidget);
  });
```

(b) 测试「重新生成会再次调用仓储」（136-153 行）当前用 `find.descendant(of: find.byType(AppBar), matching: find.byTooltip('重新生成'))`——`AppBar` 移除后失败。改为直接 `find.byTooltip('重新生成')`，但需排除气泡内的同名按钮。最稳妥：点顶层按钮用 `find.byTooltip('重新生成').first`：

```dart
  testWidgets('重新生成会再次调用仓储', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士'));
    await tester.pumpAndSettle();
    expect(repo.streamCalls, 1);

    await tester.tap(find.byTooltip('重新生成').first);
    await tester.pumpAndSettle();
    expect(repo.streamCalls, 2);
  });
```

(c) 在 `main()` 末尾追加一个新测试，断言「不再有 AppBar 实体栏」与「左上按钮点击跳转首页」：

```dart
  testWidgets('不再渲染 AppBar 实体栏', (tester) async {
    await tester.pumpWidget(
      _wrap(_StreamChatRepo(() => Stream.fromIterable(const ['x']))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('点击左上新对话按钮跳转首页', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['x']));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const ChatPage(sessionId: 's_test'),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Text('home-marker'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAppConfigProvider.overrideWithValue(
            const AppConfig(llm: LlmConfig(apiKey: 'test-key')),
          ),
          chatRepositoryProvider.overrideWithValue(repo),
          recommendationNeedClassifierProvider.overrideWithValue(
            const _FakeNeedClassifier(false),
          ),
          quickActionsSourceProvider.overrideWithValue(
            const _FailingQuickActionsSource(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // 注意：本测试 ChatPage 在 '/' 路由，context.go('/home') 验证跳转能力。
    await tester.tap(find.byTooltip('新对话'));
    await tester.pumpAndSettle();

    expect(find.text('home-marker'), findsOneWidget);
  });
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/features/chat/chat_page_test.dart`
Expected: FAIL —— 「不再渲染 AppBar」「点击左上跳转」「重新生成」等因 `AppBar` 仍存在 / 按钮未改为 `FloatingTopButton` 而失败。

- [ ] **Step 3: 修改 chat_page.dart —— 移除 AppBar，改 Stack 顶层悬浮按钮**

定位 `build` 方法当前 `return Scaffold(...)`（约 125-213 行）。当前 `Scaffold` 直接是 `appBar: AppBar(...)` + `body: Stack(...)`。改为 `Scaffold` 无 `appBar`，`body` 的 `Stack` 内顶层加两个 `Positioned` 按钮，`ListView` padding 改 56。

原 `Scaffold` 起始（125-144 行）：

```dart
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          isNewSession ? '找导师' : '继续追问',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            tooltip: '重新生成',
            onPressed: state.canRegenerate
                ? () => ref.read(_provider.notifier).regenerate()
                : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: CoolScaffoldBackground()),
```

改为（删 `appBar`，`body` 的 `Stack` 紧接 `Scaffold(`）：

```dart
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: CoolScaffoldBackground()),
```

然后在 `Stack` 的 `children` 末尾、`CoolScaffoldBackground` 之后，追加两个悬浮按钮。`Stack` 当前结构为 `Positioned.fill(CoolScaffoldBackground())` + `blocked ? ErrorView : SafeArea(Column(...))`。在 SafeArea 块**之后**（即 `]` 闭合 `Stack.children` 之前）追加：

```dart
          // 左上悬浮：「新对话」→ 回首页（首页即新会话入口）。
          Positioned(
            top: 8,
            left: 12,
            child: FloatingTopButton(
              icon: Icons.edit_square,
              tooltip: '新对话',
              onPressed: () => context.go('/'),
            ),
          ),
          // 右上悬浮：「重新生成」；canRegenerate=false 时 disabled。
          Positioned(
            top: 8,
            right: 12,
            child: FloatingTopButton(
              icon: Icons.refresh,
              tooltip: '重新生成',
              onPressed: state.canRegenerate
                  ? () => ref.read(_provider.notifier).regenerate()
                  : null,
            ),
          ),
```

- [ ] **Step 4: 调 ListView 顶部 padding**

定位 `body` 内 `SafeArea > Column > Expanded > ListView.builder`（约 153-159 行）：

```dart
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
```

改为：

```dart
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
```

- [ ] **Step 5: 加 import**

在 `chat_page.dart` 顶部 import 区追加：

```dart
import '../../../shared/widgets/floating_top_button.dart';
```

- [ ] **Step 6: 运行对话页测试，确认通过**

Run: `flutter test test/features/chat/chat_page_test.dart`
Expected: PASS（含调整后与新增测试全绿）。

- [ ] **Step 7: 静态检查**

Run: `flutter analyze lib/features/chat/pages/chat_page.dart test/features/chat/chat_page_test.dart`
Expected: 无 error/warning。注意移除 `AppBar` 后 `Theme.of(context).textTheme.titleLarge` 若不再被使用需清理——检查 `build` 内是否还有引用，若 `isNewSession` 变量仅原 `title` 用到，移除标题后 `isNewSession` 可能变成未使用变量，需一并删除其声明（约 111 行 `final isNewSession = widget.initialPrompt != null;`），保留 `showWelcome`。

- [ ] **Step 8: 提交**

```bash
git add lib/features/chat/pages/chat_page.dart test/features/chat/chat_page_test.dart
git commit -m "refactor(chat): 移除透明 AppBar 改用悬浮按钮，标题不再显示"
```

---

## Task 4: 全量回归与验证

**Files:** 无新文件，仅运行验证。

**Interfaces:** 无。

- [ ] **Step 1: 全量测试**

Run: `flutter test`
Expected: 全绿。重点关注：
- `test/features/home/home_page_test.dart`（含 right-edge swipe 测试，`top:56` 后 fling 起点 `Offset(size.width-10, 200)` 仍 > 56）。
- `test/features/home/home_page_conversation_test.dart`（既有「新对话」tooltip 断言）。
- `test/features/chat/chat_page_test.dart`（调整后断言）。
- `test/shared/widgets/floating_top_button_test.dart`。

- [ ] **Step 2: 全量静态检查**

Run: `flutter analyze`
Expected: 无 error/warning。

- [ ] **Step 3: 手动验证清单（如运行环境允许）**

在 Windows 桌面或 Android 模拟器启动 app，确认：
- 首页落地态：左上空、右上菜单按钮（圆形玻璃），logo 与 prompt 网格不被遮挡。
- 首页对话态：左上「新对话」、右上「菜单」，第一条消息不被按钮遮挡（顶部有 56 避让）。
- 首页右滑边缘可开抽屉（从 56px 以下起滑）。
- 对话页：左上「新对话」、右上「重新生成」（busy/不可生成时置灰），消息流顶部有避让。
- 对话页点左上「新对话」→ 回首页。

- [ ] **Step 4: 提交（如有手动验证产生的微调）**

若 Step 3 发现视觉问题并调整，提交：

```bash
git add -A
git commit -m "fix(chat/home): 悬浮按钮视觉微调"
```

若无调整，本 Task 无需额外提交。

---

## Self-Review 结论

**1. Spec 覆盖**：
- FloatingTopButton 组件（含 disabled）→ Task 1。
- 首页移栏改悬浮 + ListView padding + RightEdgeOpenDrawer.top → Task 2 Step 3/4/5。
- 对话页移 AppBar 改悬浮 + ListView padding → Task 3 Step 3/4。
- 新增组件测试、首页测试、对话页测试 → Task 1/2/3 各自 Step 1。
- 回归清单（CoolScaffoldBackground/AppMenuDrawer/RightEdgeOpenDrawer/regenerate/stop/键盘）→ Task 4 Step 1/3。
- 现有测试调整（chat 页标题「继续追问」、AppBar descendant 断言）→ Task 3 Step 1(a)(b)。

**2. 占位扫描**：无 TBD/TODO；每步含完整代码。

**3. 类型一致**：`FloatingTopButton` 构造签名（`icon`/`tooltip`/`onPressed`）在 Task 1 定义，Task 2/3 消费时参数名一致；tooltip 文案「新对话」「菜单」「重新生成」全计划统一。
