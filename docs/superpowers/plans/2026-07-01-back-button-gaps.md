# 返回键缺口修补 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修补 chat / profile_intro / profile_wizard / competition_detail 四页的移动端返回交互缺口，让顶栏返回键与系统返回手势行为一致且符合预期。

**Architecture:** 每页就地修补，不引入新组件/路由/状态管理。chat 用 `PopScope` 把顶栏返回箭头与系统返回手势收口到「生成中拦截确认」逻辑；wizard 用 `PopScope` 让 step>0 时返回走 step-back；intro 加 `AppBar`；competition_detail 空态补标题。

**Tech Stack:** Flutter 3.44.1 / Dart 3.12.1，flutter_riverpod，go_router，`PopScope`（`onPopInvokedWithResult` 新签名），`Haptics`。

## Global Constraints

- 项目 Flutter 版本 3.44.1（Dart 3.12.1）；用 `PopScope`，不用已废弃的 `WillPopScope`；用 `onPopInvokedWithResult`（3.22+ 新签名，带 `result` 参数）。
- 不新增 provider / 路由 / widget 文件；不引入新依赖。
- 保留中文产品文案风格。
- 每个任务先写失败测试，再实现，再跑测试，最后 commit。
- UI 改动需手测（计划末尾有手测清单任务）。

---

## File Structure

修改文件（无新建）：

- `lib/features/chat/pages/chat_page.dart` —— 加 `PopScope` 包裹 `Scaffold`，新增 `_isStreaming` / `_confirmExit` / `_handleBack` 方法；改两处返回按钮 `onPressed`。
- `lib/features/profile/pages/profile_intro_page.dart` —— `Scaffold` 加 `appBar`。
- `lib/features/profile/widgets/wizard_scaffold.dart` —— `AppBar` leading 透传 `onBack`；新增 `canPop` + `onSystemBack` 参数，外层包 `PopScope`。
- `lib/features/profile/pages/profile_wizard_page.dart` —— 向 `WizardScaffold` 传入 `canPop` / `onSystemBack`。
- `lib/features/competition_recommendation/pages/competition_detail_page.dart` —— 三处空 `AppBar()` 补标题。

测试文件（无新建，追加用例）：

- `test/features/chat/chat_page_test.dart`
- `test/features/profile/profile_wizard_page_test.dart`
- `test/features/profile/profile_intro_page_test.dart`（若不存在则新建）
- `test/features/competition_recommendation/competition_detail_page_test.dart`（若不存在则新建）

---

## Task 1: competition_detail_page 空态 AppBar 补标题

最简单、最隔离的改动，先做以建立 commit 节奏。

**Files:**
- Modify: `lib/features/competition_recommendation/pages/competition_detail_page.dart:32-33, 48-49, 52-53`
- Test: `test/features/competition_recommendation/pages/competition_detail_page_test.dart`（已存在，追加用例）

**Interfaces:**
- Consumes: 无
- Produces: 无（纯视觉改动，无对外接口变化）

**背景：** 该测试文件已存在，且已有 `'未知 id 显示未找到'` 用例（第 110 行），但它只断言 `find.textContaining('未找到')`，没断言 AppBar 标题。当前空 `AppBar()` 返回键其实会显示（`automaticallyImplyLeading` 默认 true），只是无标题。本次新增对 AppBar 标题的断言。

- [ ] **Step 1: 写失败测试（追加到现有 test 文件）**

打开 `test/features/competition_recommendation/pages/competition_detail_page_test.dart`，在 `main()` 内追加（复用文件顶部已有的 `bootstrap()` 与 `_catalog`）：

```dart
  testWidgets('未知 id 空态 AppBar 标题为「竞赛详情」', (t) async {
    final container = await bootstrap();
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: CompetitionDetailPage(competitionId: 'nope'),
        ),
      ),
    );
    await t.pumpAndSettle();

    final appBar = t.widget<AppBar>(find.byType(AppBar));
    final title = appBar.title;
    expect(title, isA<Text>());
    expect((title as Text).data, '竞赛详情');
  });
```

注意：现有文件用 `t` 作为 `WidgetTester` 参数名（见第 93 行 `(t) async`），新用例也用 `t` 保持一致。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/competition_recommendation/pages/competition_detail_page_test.dart --plain-name "未知 id 空态 AppBar 标题为"`
Expected: FAIL —— 当前 `appBar: AppBar()` 的 `title` 为 null，`(title as Text)` 抛 `type 'Null' is not a subtype`。

- [ ] **Step 3: 修改三处空 AppBar 补标题**

打开 `lib/features/competition_recommendation/pages/competition_detail_page.dart`，把第 33、49、53 行的：

```dart
appBar: AppBar(),
```

三处全部改为：

```dart
appBar: AppBar(title: const Text('竞赛详情')),
```

（第 33 行在 `base == null` 分支；第 49 行在 `loading` 分支；第 53 行在 `error` 分支。主态第 92 行的 `AppBar(title: Text(merged.name...))` 不动。）

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/features/competition_recommendation/pages/competition_detail_page_test.dart`
Expected: PASS（含原有用例 + 新用例）。

- [ ] **Step 5: 跑 analyze + format**

Run: `flutter analyze lib/features/competition_recommendation/pages/competition_detail_page.dart test/features/competition_recommendation/pages/competition_detail_page_test.dart`
Expected: 无新增 error/warning。

Run: `dart format lib/features/competition_recommendation/pages/competition_detail_page.dart test/features/competition_recommendation/pages/competition_detail_page_test.dart`
Expected: 格式无变化（或已自动 format）。

- [ ] **Step 6: Commit**

```bash
git add lib/features/competition_recommendation/pages/competition_detail_page.dart test/features/competition_recommendation/pages/competition_detail_page_test.dart
git commit -m "fix(competition-detail): 空态 AppBar 补「竞赛详情」标题"
```

---

## Task 2: profile_intro_page 加 AppBar

**Files:**
- Modify: `lib/features/profile/pages/profile_intro_page.dart:16-17`
- Test: `test/features/profile/profile_intro_page_test.dart`（新建）

**Interfaces:**
- Consumes: 无
- Produces: 无（`ProfileIntroPage` 对外接口不变）

- [ ] **Step 1: 写失败测试（新建测试文件）**

新建 `test/features/profile/profile_intro_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/features/profile/pages/profile_intro_page.dart';

Widget _harness() {
  final router = GoRouter(
    initialLocation: '/profile/intro',
    routes: [
      GoRoute(path: '/profile/intro', builder: (_, _) => const ProfileIntroPage()),
      GoRoute(path: '/profile', builder: (_, _) => const Text('hub-marker')),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('顶栏 AppBar 标题为「完善档案」', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.text('完善档案'), findsOneWidget);
  });

  testWidgets('底部「以后再说」仍存在并可点击返回', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.text('以后再说'), findsOneWidget);
    await tester.tap(find.text('以后再说'));
    await tester.pumpAndSettle();
    // pop 回无上一页 → 路由停在原地，无崩溃即通过。
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/profile/profile_intro_page_test.dart`
Expected: FAIL —— `find.text('完善档案')` finds nothing（当前无 AppBar）。

- [ ] **Step 3: 给 Scaffold 加 appBar**

打开 `lib/features/profile/pages/profile_intro_page.dart`，把第 16 行：

```dart
return Scaffold(
  body: SafeArea(
```

改为：

```dart
return Scaffold(
  appBar: AppBar(title: const Text('完善档案')),
  body: SafeArea(
```

（顶部 `import` 已有 `flutter/material.dart`，无需新增 import。）

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/features/profile/profile_intro_page_test.dart`
Expected: PASS

- [ ] **Step 5: 跑 analyze + format**

Run: `flutter analyze lib/features/profile/pages/profile_intro_page.dart test/features/profile/profile_intro_page_test.dart`
Expected: 无新增 error/warning。

Run: `dart format lib/features/profile/pages/profile_intro_page.dart test/features/profile/profile_intro_page_test.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/profile/pages/profile_intro_page.dart test/features/profile/profile_intro_page_test.dart
git commit -m "fix(profile-intro): 加顶栏 AppBar 返回键"
```

---

## Task 3: profile_wizard 顶栏箭头联动 step-back + PopScope

**Files:**
- Modify: `lib/features/profile/widgets/wizard_scaffold.dart:6-35`（加参数 + leading + PopScope）
- Modify: `lib/features/profile/pages/profile_wizard_page.dart:75-83`（传 canPop/onSystemBack）
- Test: `test/features/profile/profile_wizard_page_test.dart`（追加用例）

**Interfaces:**
- Consumes: `WizardScaffold` 现有 `onBack`（已有，代表 step-back）
- Produces: `WizardScaffold` 新增两个可选参数 `canPop`（默认 `true`）与 `onSystemBack`（`VoidCallback?`），供 `ProfileWizardPage` 传入。

- [ ] **Step 1: 写失败测试（追加到现有 test 文件）**

打开 `test/features/profile/profile_wizard_page_test.dart`，在 `main()` 内追加：

```dart
  testWidgets('step>0 点顶栏返回箭头回退上一步（不退出）', (tester) async {
    final repo = _MemProfileRepo();
    final router = GoRouter(
      initialLocation: '/profile/wizard',
      routes: [
        GoRoute(
          path: '/profile/wizard',
          builder: (_, _) => const ProfileWizardPage(),
        ),
        GoRoute(path: '/profile', builder: (_, _) => const Text('hub-marker')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '张三');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 在 step 1：点顶栏返回箭头 → 回到 step 0（标题变回「基本信息」）
    final backButton = find.byTooltip('上一步');
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('成绩 & 方向'), findsNothing);
  });

  testWidgets('step>0 系统返回手势回退上一步（不退出）', (tester) async {
    final repo = _MemProfileRepo();
    final router = GoRouter(
      initialLocation: '/profile/wizard',
      routes: [
        GoRoute(
          path: '/profile/wizard',
          builder: (_, _) => const ProfileWizardPage(),
        ),
        GoRoute(path: '/profile', builder: (_, _) => const Text('hub-marker')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '张三');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 模拟系统返回：PopScope 拦截后调 onSystemBack
    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
    expect(find.text('成绩 & 方向'), findsOneWidget);
  });

  testWidgets('step 0 顶栏默认返回箭头 pop 整页', (tester) async {
    final repo = _MemProfileRepo();
    final router = GoRouter(
      initialLocation: '/profile/wizard',
      routes: [
        GoRoute(
          path: '/profile/wizard',
          builder: (_, _) => const ProfileWizardPage(),
        ),
        GoRoute(path: '/profile', builder: (_, _) => const Text('hub-marker')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // step 0：无「上一步」tooltip 的自定义箭头，用默认 BackButton
    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isTrue);
  });
```

注意：`_MemProfileRepo` 已在文件顶部定义（见第 10-20 行），直接复用。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/profile/profile_wizard_page_test.dart`
Expected: FAIL —— 当前无 `PopScope`，`find.byType(PopScope)` 抛 `A PopScope is not found`；step>0 点「上一步」tooltip 找不到（当前顶栏箭头无此 tooltip）。

- [ ] **Step 3: 改 WizardScaffold —— 加参数 + leading + PopScope**

打开 `lib/features/profile/widgets/wizard_scaffold.dart`。把构造函数和字段（第 7-24 行）改为：

```dart
class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    super.key,
    required this.title,
    required this.index,
    required this.count,
    required this.child,
    required this.onNext,
    required this.nextLabel,
    this.onBack,
    this.canPop = true,
    this.onSystemBack,
  });

  final String title;
  final int index;
  final int count;
  final Widget child;
  final VoidCallback onNext;
  final String nextLabel;
  final VoidCallback? onBack;

  /// step 0：true（系统返回手势直接 pop 整页）；step>0：false（走 [onSystemBack] step-back）。
  final bool canPop;
  final VoidCallback? onSystemBack;
```

把 `build` 方法（第 27 行起）的 `return Scaffold(...)` 改为外层包 `PopScope`：

```dart
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (onSystemBack != null) onSystemBack!();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('完善个人档案'),
          leading: onBack == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: '上一步',
                  onPressed: () {
                    Haptics.light();
                    onBack!();
                  },
                ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: StepDots(count: count, index: index),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(title, style: textTheme.headlineSmall),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: child,
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (onBack != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Haptics.light();
                              onBack!();
                            },
                            child: const Text('上一步'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Haptics.light();
                            onNext();
                          },
                          child: Text(nextLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

（`body` 内部 Column 结构原样保留，只是缩进多一层。）

- [ ] **Step 4: 改 ProfileWizardPage —— 传 canPop/onSystemBack**

打开 `lib/features/profile/pages/profile_wizard_page.dart`，把 `build` 方法里的 `return WizardScaffold(...)`（第 75-84 行）改为：

```dart
    return WizardScaffold(
      title: title,
      index: _step,
      count: 3,
      onBack: _step == 0 ? null : _back,
      onSystemBack: _step == 0 ? null : _back,
      canPop: _step == 0,
      onNext: _next,
      nextLabel: _step == 2 ? '完成' : '下一步',
      child: child,
    );
```

- [ ] **Step 5: 跑测试确认通过**

Run: `flutter test test/features/profile/profile_wizard_page_test.dart`
Expected: PASS（含原有用例 + 3 个新用例）。

- [ ] **Step 6: 跑 analyze + format**

Run: `flutter analyze lib/features/profile/widgets/wizard_scaffold.dart lib/features/profile/pages/profile_wizard_page.dart test/features/profile/profile_wizard_page_test.dart`
Expected: 无新增 error/warning。

Run: `dart format lib/features/profile/widgets/wizard_scaffold.dart lib/features/profile/pages/profile_wizard_page.dart test/features/profile/profile_wizard_page_test.dart`

- [ ] **Step 7: Commit**

```bash
git add lib/features/profile/widgets/wizard_scaffold.dart lib/features/profile/pages/profile_wizard_page.dart test/features/profile/profile_wizard_page_test.dart
git commit -m "fix(profile-wizard): 顶栏返回箭头与系统手势 step>0 时回退上一步"
```

---

## Task 4: chat_page PopScope 生成中拦截确认

最复杂的改动放最后。

**Files:**
- Modify: `lib/features/chat/pages/chat_page.dart:158`（PopScope 包 Scaffold）、`323-327` 与 `351-355`（两处返回按钮 onPressed）
- Test: `test/features/chat/chat_page_test.dart`（追加用例）

**Interfaces:**
- Consumes: `ChatState.activity == ChatActivity.streaming`（现有枚举）、`ChatNotifier.stop()`（现有方法，见 `chat_provider.dart:430`）
- Produces: 无（ChatPage 对外接口不变）

- [ ] **Step 1: 写失败测试（追加到现有 test 文件）**

打开 `test/features/chat/chat_page_test.dart`，在 `main()` 内追加。复用现有 `_wrap` 和 `_StreamChatRepo`：

```dart
  testWidgets('生成中点返回箭头弹确认对话框，取消则不退出', (tester) async {
    final controller = StreamController<String>();
    addTearDown(controller.close);
    await tester.pumpWidget(_wrap(_StreamChatRepo(() => controller.stream)));
    await tester.pumpAndSettle();

    // 触发流式
    await tester.tap(find.text('适合硕士'));
    await tester.pump();
    controller.add('部分答案');
    await tester.pump();

    // 点左上「返回」
    await tester.tap(find.byTooltip('返回').first);
    await tester.pumpAndSettle();

    // 弹确认框
    expect(find.text('正在生成中'), findsOneWidget);
    expect(find.text('继续生成'), findsOneWidget);
    expect(find.text('离开'), findsOneWidget);

    // 取消
    await tester.tap(find.text('继续生成'));
    await tester.pumpAndSettle();

    // 对话框关闭，仍在 chat 页
    expect(find.text('正在生成中'), findsNothing);
    expect(find.byType(ChatPage), findsOneWidget);
  });

  testWidgets('非生成态点返回箭头直接 pop，无对话框', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // 未触发流式 → 非生成态
    expect(find.text('正在生成中'), findsNothing);

    await tester.tap(find.byTooltip('返回').first);
    await tester.pumpAndSettle();

    // 直接退出，无对话框
    expect(find.text('正在生成中'), findsNothing);
  });

  testWidgets('生成中按系统返回手势也弹确认框', (tester) async {
    final controller = StreamController<String>();
    addTearDown(controller.close);
    await tester.pumpWidget(_wrap(_StreamChatRepo(() => controller.stream)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士'));
    await tester.pump();
    controller.add('部分答案');
    await tester.pump();

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
  });

  testWidgets('生成中确认离开后调用 stop 并 pop', (tester) async {
    final controller = StreamController<String>();
    addTearDown(controller.close);
    final repo = _StreamChatRepo(() => controller.stream);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士'));
    await tester.pump();
    controller.add('部分答案');
    await tester.pump();

    await tester.tap(find.byTooltip('返回').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('离开'));
    await tester.pumpAndSettle();

    // 确认后对话框关闭、页面退出
    expect(find.text('正在生成中'), findsNothing);
  });
```

注意：`StreamController` 和 `_StreamChatRepo` 已在文件顶部 import / 定义（见第 1、35 行）。`ChatPage` 已在第 29 行 import。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/chat/chat_page_test.dart --plain-name "生成中点返回箭头弹确认对话框"`
Expected: FAIL —— 当前点返回直接 `context.pop()`，无确认框，`find.text('正在生成中')` finds nothing。

- [ ] **Step 3: 改 chat_page —— 加 PopScope + 辅助方法**

打开 `lib/features/chat/pages/chat_page.dart`。

3a. 在 `_ChatPageState` 类内（`build` 方法之前，约第 131 行 `Widget build` 上方）新增三个方法。`_ChatPageState` 是 `ConsumerState`，`ref` 直接可用，无需作为参数传入：

```dart
  bool _isStreaming(ChatState state) =>
      state.activity == ChatActivity.streaming;

  Future<bool> _confirmExit(BuildContext context) async {
    if (!_isStreaming(ref.read(_provider))) return true;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('正在生成中'),
        content: const Text('当前对话正在生成，离开会中断本轮。要离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('继续生成'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('离开'),
          ),
        ],
      ),
    );
    if (shouldLeave == true) {
      await ref.read(_provider.notifier).stop();
    }
    return shouldLeave ?? false;
  }

  Future<void> _handleBack(BuildContext context) async {
    final shouldLeave = await _confirmExit(context);
    if (shouldLeave && context.mounted) context.pop();
  }
```

注意：`ChatActivity` 与 `ChatState` 已通过 `../providers/chat_provider.dart`（第 18 行）import，`context.pop` 来自 `go_router`（第 3 行已 import），`ChatActivity` 是公开枚举（`chat_provider.dart:16`）。`ref` 是 `ConsumerState` 提供的字段（文件中第 71、111 行已直接使用 `ref.read(...)`，同此模式）。

3b. 把第 158 行 `return Scaffold(` 改为外层包 `PopScope`（注意缩进整体下移，`Scaffold` 内部不变）：

```dart
    return PopScope(
      canPop: !_isStreaming(state),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _confirmExit(context);
        if (shouldLeave && context.mounted) context.pop();
      },
      child: Scaffold(
        body: Stack(
```

（`Scaffold` 结尾的 `);` 对应位置需补一个 `)` 闭合 `PopScope`。原 `return Scaffold(...);` 的最后 `);` 改为 `),);` 即 `child: Scaffold(...)` 收尾后再 `)` 关 `PopScope`。）

3c. 把 fork 页返回箭头（第 323-327 行）的：

```dart
                  leading: FloatingTopButton(
                    icon: Icons.arrow_back,
                    tooltip: '返回',
                    onPressed: () => context.pop(),
                  ),
```

改为：

```dart
                  leading: FloatingTopButton(
                    icon: Icons.arrow_back,
                    tooltip: '返回',
                    onPressed: () => _handleBack(context),
                  ),
```

3d. 把普通页返回箭头（第 351-355 行）的：

```dart
                  : FloatingTopButton(
                      icon: Icons.arrow_back,
                      tooltip: '返回',
                      onPressed: () => context.pop(),
                    ),
```

改为：

```dart
                  : FloatingTopButton(
                      icon: Icons.arrow_back,
                      tooltip: '返回',
                      onPressed: () => _handleBack(context),
                    ),
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/features/chat/chat_page_test.dart`
Expected: PASS（含原有用例 + 4 个新用例）。

- [ ] **Step 5: 跑 analyze + format**

Run: `flutter analyze lib/features/chat/pages/chat_page.dart test/features/chat/chat_page_test.dart`
Expected: 无新增 error/warning。

Run: `dart format lib/features/chat/pages/chat_page.dart test/features/chat/chat_page_test.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/chat/pages/chat_page.dart test/features/chat/chat_page_test.dart
git commit -m "fix(chat): 生成中返回拦截确认，顶栏箭头与系统手势统一"
```

---

## Task 5: 全量验证 + 手测

**Files:**
- 无文件改动，纯验证。

- [ ] **Step 1: 跑受影响模块全量测试**

Run: `flutter test test/features/chat/ test/features/profile/ test/features/competition_recommendation/`
Expected: 全绿。

- [ ] **Step 2: 跑 analyze 全量**

Run: `flutter analyze`
Expected: 无新增 error/warning（与改动前 baseline 持平）。

- [ ] **Step 3: format 检查**

Run: `dart format --set-exit-if-changed lib test`
Expected: 退出码 0（无未格式化文件）。

- [ ] **Step 4: 手测清单（CLAUDE.md 要求 UI 改动手测）**

启动 app，逐项验证（Android 模拟器/真机 + iOS 模拟器各一遍，至少 Android）：

1. chat 生成中按系统返回 → 确认框出现 → 取消 → 会话仍在；确认 → 回上一页且流式停止。
2. chat 非生成态返回 → 秒回，无确认框。
3. chat fork 追问页生成中点顶栏返回 → 同主分支行为（弹确认框）。
4. intro 页顶栏返回箭头 → 回上一页；底部「以后再说」仍可用。
5. wizard step 1 顶栏箭头 → 回到 step 0；step 0 顶栏箭头 → 退出 wizard。
6. wizard step 1 系统返回手势 → 回到 step 0（与顶栏一致）。
7. 竞赛详情 loading / 错误 / 空态 → 顶栏有「竞赛详情」标题 + 返回键。

- [ ] **Step 5: 记录验证结果**

若全部通过，向用户报告完成。若有任何手测项失败，回到对应 Task 修复。若本地无法起设备/模拟器，明确说明哪些项未手测。

---

## Self-Review 结果

- **Spec 覆盖**：spec §2.1 chat → Task 4；§2.2 intro → Task 2；§2.3 wizard → Task 3；§2.4 competition_detail → Task 1；spec §4 测试与手测 → Task 5。全覆盖。
- **占位符扫描**：无 TBD/TODO，每个代码步骤都有完整代码。
- **类型一致性**：`WizardScaffold` 新增参数 `canPop`（bool，默认 true）/ `onSystemBack`（VoidCallback?），Task 3 定义与使用一致；chat 的 `_isStreaming` / `_confirmExit` / `_handleBack` 签名在定义与调用处一致。
