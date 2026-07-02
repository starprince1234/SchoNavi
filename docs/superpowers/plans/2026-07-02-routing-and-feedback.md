# 引导页回退栈修复 + 反馈交互重设计 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复冷启动进入「我的档案」引导页回退需按两次的路由 bug，并把 AI 回复下的反馈按钮重设计为 ChatGPT/豆包式统一动作条（复制/赞/踩 + 点踩内联输入）+ 导师卡片长按反馈。

**Architecture:** 问题 1 在抽屉入口单点决策（空 profile 直接进 `/profile/intro`，避免 `/profile→/profile/intro` 双层栈），并把 ProfilePage 的导航副作用从 `build()` 移到 `initState` 一次性哨兵，消除回退后重复 push。问题 2 删除孤立外框感叹号按钮，统一 `_MessageActions`（conversation + recommendation 共用），点踩内联展开输入框走既有 `feedbackSubmitProvider`；`SwipeRecommendationCard` 加 `onLongPress` 弹「推荐不准/信息不准确」反馈 sheet。

**Tech Stack:** Flutter/Dart、flutter_riverpod 3.2.1、go_router、`feedbackSubmitProvider`（既有）、`showAppBottomSheet`（既有）。

## Global Constraints

- 不引入新状态管理/路由/HTTP 库。
- 不改 LLM 路径与 provider；不动 `FeedbackRepository` / `Feedback` / `FeedbackContext` / `feedbackSubmitProvider` / `ChatNotifier.setFeedback` 接口。
- 默认无注释；仅在原因不明显处加短注释。
- 保留中文产品文案风格。
- 提交按 `feat`/`fix` 前缀；每个 Task 末尾 commit（用户未要求 push/PR，仅 commit 到本地工作树）。
- 受 Drift 测试 hang 影响的全量 `flutter test` 不在必跑范围（既有问题）；每 Task 跑针对性测试 + `flutter analyze`。

**关键既有接点（供各 Task 引用）：**
- `ChatMessageBubble.onFeedback(messageId, ChatMessageFeedback)` → `ChatNotifier.setFeedback`（[chat_provider.dart:381](../../lib/features/chat/providers/chat_provider.dart)），赞/踩沿用。
- `feedbackSubmitProvider.submit({type, content, contact, context})` → `FeedbackRepository.submit`（[feedback_provider.dart:37](../../lib/features/feedback/providers/feedback_provider.dart)）。
- `FeedbackContext.fromQuery` / `FeedbackContext({route,sessionId,messageId,professorId,competitionId,prompt,appVersion,dataSourceMode})`（[feedback.dart](../../lib/domain/entities/feedback.dart)）。
- `FeedbackType { recommendation, missingProfessor, bug, other }`。
- `showAppBottomSheet({context, builder})`（[core/ui/app_bottom_sheet.dart](../../lib/core/ui/app_bottom_sheet.dart)）。
- `SwipeRecommendationCard` 现有手势：`onTap`(整体)、`onFavoritePressed`(Listener 包裹 IconButton)、`onOpenUrlPressed`（[swipe_recommendation_card.dart](../../lib/shared/widgets/swipe_recommendation_card.dart)）。
- 既有测试 `test/features/chat/chat_message_bubble_test.dart:313-325` 断言 `find.byTooltip('反馈这条推荐')` —— 本计划会改掉它。

---

## 文件结构

**新增：**
- `lib/features/chat/widgets/inline_dislike_feedback.dart` — 点踩内联输入框组件（TextField + 提交/收起）。
- `lib/features/chat/widgets/recommendation_feedback_sheet.dart` — 长按导师卡片的反馈 bottom sheet（预设理由 + 补充说明）。
- `test/features/chat/widgets/inline_dislike_feedback_test.dart`
- `test/features/chat/widgets/recommendation_feedback_sheet_test.dart`
- `test/shared/widgets/app_menu_drawer_profile_route_test.dart`

**修改：**
- `lib/shared/widgets/app_menu_drawer.dart` — `_navigate` 对 `/profile` 空态分流。
- `lib/features/profile/pages/profile_page.dart` — 转 `ConsumerStatefulWidget`，删 build 副作用，加 `initState` 哨兵。
- `lib/features/chat/widgets/chat_message_bubble.dart` — 删孤立感叹号按钮；`_MessageActions` 转 StatefulWidget + 统一覆盖 + 赞/踩/复制/重新生成 + 内联展开；新增 `onDislikeFeedback`；给 `RecommendationCarousel` 透传上下文。
- `lib/features/chat/widgets/recommendation_carousel.dart` — 新增 `onReportRecommendation` + 上下文参数透传给卡片 `onLongPress`。
- `lib/shared/widgets/swipe_recommendation_card.dart` — 新增 `onLongPress`，与 onTap/onFavoritePressed 手势协调。
- `lib/features/chat/pages/chat_page.dart` — 注入 `onDislikeFeedback`、`onReportRecommendation`，透传上下文。
- `lib/features/home/pages/home_page.dart` — 同步注入新回调（home 也用 ChatMessageBubble）。
- `test/features/chat/chat_message_bubble_test.dart` — 改掉 `反馈这条推荐` tooltip 断言，加新动作条/内联展开/长按断言。
- `test/shared/widgets/swipe_recommendation_card_test.dart` — 加长按回调测试。
- `test/features/profile/profile_page_test.dart` — 加「空 profile 只触发一次引导 push」「rebuild 不重复 push」测试。

---

## Task 1: ProfilePage 一次性哨兵 + 移除 build 副作用

**Files:**
- Modify: `lib/features/profile/pages/profile_page.dart`
- Test: `test/features/profile/profile_page_test.dart`

**Interfaces:**
- Consumes: `profileProvider`（`NotifierProvider<ProfileController, UserProfile>`）、`localStoreProvider.getBool('privacy_agreed')`、`UserProfile.isEmpty`。
- Produces: `ProfilePage` 转为 `ConsumerStatefulWidget`，行为：空 profile 在 `initState` 一次性 push `/profile/privacy` 或 `/profile/intro`，build 不再有导航副作用。

- [ ] **Step 1: 写失败测试 — 空 profile 进入只 push 一次引导页**

在 `test/features/profile/profile_page_test.dart` 的 `main()` 内追加（保留现有 `_Repo` 与 import）：

```dart
testWidgets('空 profile 只触发一次引导 push', (tester) async {
  final pushed = <String>[];
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, _) => const ProfilePage(),
      ),
      GoRoute(
        path: '/profile/intro',
        builder: (_, _) => const Scaffold(body: Center(child: Text('intro'))),
      ),
      GoRoute(
        path: '/profile/privacy',
        builder: (_, _) => const Scaffold(body: Center(child: Text('privacy'))),
      ),
    ],
  );
  router.routerDelegate.addListener(() {});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(_Repo(const UserProfile())),
        localStoreProvider.overrideWithValue(_AgreedStore(agreed: true)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('intro'), findsOneWidget);
  // 回退到 profile
  router.pop();
  await tester.pumpAndSettle();
  expect(find.text('我的档案'), findsOneWidget);
  // 再 pump（模拟 rebuild）不应再跳回 intro
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('intro'), findsNothing);
  pushed; // 保留以备调试
});
```

在文件顶部 import 区追加（若已存在则跳过）：

```dart
import 'package:scho_navi/core/storage/local_store.dart';
```

并在 `main()` 之前追加辅助类：

```dart
class _AgreedStore implements LocalStore {
  _AgreedStore({required this.agreed});
  final bool agreed;
  @override
  bool? getBool(String key) => key == 'privacy_agreed' ? agreed : null;
  @override
  Future<void> setBool(String key, bool value) async {}
  @override
  Object? getJson(String key) => null;
  @override
  Future<void> setJson(String key, Object value) async {}
  @override
  Future<void> remove(String key) async {}
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/profile/profile_page_test.dart --plain-name "空 profile 只触发一次引导 push"`
Expected: FAIL（当前 build 副作用会在回退后再次 push intro，断言 `find.text('intro')` failsNothing 失败，或现有行为导致重复 push）

- [ ] **Step 3: 把 ProfilePage 改为 ConsumerStatefulWidget + initState 哨兵**

将 `lib/features/profile/pages/profile_page.dart` 顶部的 `class ProfilePage extends ConsumerWidget` 整体替换为 StatefulWidget 形态。修改要点：

把：

```dart
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final isHttp = ref.watch(
      appConfigProvider.select((cfg) => cfg.dataSource == DataSource.http),
    );

    if (profile.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final store = ref.read(localStoreProvider);
        final agreed = store.getBool('privacy_agreed') ?? false;
        if (!agreed) {
          context.push('/profile/privacy');
        } else {
          context.push('/profile/intro');
        }
      });
    }

    return Scaffold(
```

改为：

```dart
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    if (profile.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _redirected) return;
        _redirected = true;
        final store = ref.read(localStoreProvider);
        final agreed = store.getBool('privacy_agreed') ?? false;
        if (!agreed) {
          context.push('/profile/privacy');
        } else {
          context.push('/profile/intro');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final isHttp = ref.watch(
      appConfigProvider.select((cfg) => cfg.dataSource == DataSource.http),
    );

    return Scaffold(
```

然后把原 `build(BuildContext context, WidgetRef ref)` 内其余方法 `_editBasic`/`_editScore`/`_editAchievements`/`_editSheet` 的签名 `WidgetRef ref` 参数去掉、内部 `ref` 改用 `this.ref`（ConsumerState 已有 `ref`）。具体：把

```dart
  Future<void> _editBasic(BuildContext context, WidgetRef ref, UserProfile p) =>
```

改为

```dart
  Future<void> _editBasic(BuildContext context, UserProfile p) =>
```

同理 `_editScore`、`_editAchievements`、`_editSheet`（4 处 `WidgetRef ref` 参数删除）。`_editSheet` 内 `ref.read(profileProvider.notifier).save(draft)` 保持（`ref` 现为 State 的 ref）。build 内 `onUseForReco: () => context.go('/home')`、`_editBasic(context, ref, profile)` 调用改为 `_editBasic(context, profile)`（4 处调用去掉 `ref`）。

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/profile/profile_page_test.dart`
Expected: PASS（现有「展示分区卡与完成度」+ 新「空 profile 只触发一次引导 push」均通过）

- [ ] **Step 5: 运行 analyze**

Run: `flutter analyze lib/features/profile/pages/profile_page.dart`
Expected: 无新增 warning/error

- [ ] **Step 6: 提交**

```bash
git add lib/features/profile/pages/profile_page.dart test/features/profile/profile_page_test.dart
git commit -m "fix(profile): 空 profile 引导跳转改为 initState 一次性哨兵，消除回退重复 push"
```

---

## Task 2: 抽屉入口单点决策（空 profile 直接进 intro）

**Files:**
- Modify: `lib/shared/widgets/app_menu_drawer.dart`
- Test: `test/shared/widgets/app_menu_drawer_profile_route_test.dart`

**Interfaces:**
- Consumes: `profileProvider`（`ref.read(profileProvider).isEmpty`）。
- Produces: 抽屉点「我的档案」时，空 profile → `context.push('/profile/intro')`；非空 → `context.push('/profile')`。

- [ ] **Step 1: 写失败测试 — 空 profile 点档案进 intro，非空进 profile**

新建 `test/shared/widgets/app_menu_drawer_profile_route_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/shared/widgets/app_menu_drawer.dart';

class _Repo implements ProfileRepository {
  _Repo(this._p);
  UserProfile _p;
  @override
  UserProfile load() => _p;
  @override
  Future<UserProfile> refresh() async => load();
  @override
  Future<void> save(UserProfile profile) async => _p = profile;
  @override
  Future<void> clear() async {}
}

Widget _harness(UserProfile profile) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(path: '/profile', builder: (_, _) => const Scaffold(body: Text('profile-page'))),
      GoRoute(path: '/profile/intro', builder: (_, _) => const Scaffold(body: Text('intro-page'))),
    ],
  );
  return ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(_Repo(profile)),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      // 让 Drawer 能在测试里打开
      builder: (context, child) => Navigator(
        onGenerateRoute: (s) => MaterialPageRoute(
          builder: (_) => Scaffold(
            drawer: const AppMenuDrawer(),
            body: const Center(child: Text('home')),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // 抽屉的 profile 头像入口 onTap 直接走 _navigate(context, '/profile')。
  // 本测试用 DrawerTile「我的档案」不可达（它在 drawer 内），故直接验证 _navigate 行为：
  // 通过打开 drawer 点头部入口触发。
  testWidgets('空 profile：点档案头进入 /profile/intro', (tester) async {
    await tester.pumpWidget(_harness(const UserProfile()));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(800, 400), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('档案'));
    await tester.pumpAndSettle();
    expect(find.text('intro-page'), findsOneWidget);
  });

  testWidgets('非空 profile：点档案头进入 /profile', (tester) async {
    await tester.pumpWidget(
      _harness(const UserProfile(name: '张三', gender: Gender.male)),
    );
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(800, 400), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('档案'));
    await tester.pumpAndSettle();
    expect(find.text('profile-page'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/shared/widgets/app_menu_drawer_profile_route_test.dart`
Expected: FAIL（当前 `点档案头` 都进入 `/profile`，空 profile 用例期望 intro 失败）

- [ ] **Step 3: 修改抽屉 _navigate 对 /profile 空态分流**

在 `lib/shared/widgets/app_menu_drawer.dart` 的 `AppMenuDrawer.build` 内，把

```dart
            // ── 顶部档案入口 ─────────────────────────────────────────────
            _ProfileHeader(onTap: () => _navigate(context, '/profile')),
```

改为：

```dart
            // ── 顶部档案入口 ─────────────────────────────────────────────
            _ProfileHeader(
              onTap: () => _navigate(
                context,
                ref.read(profileProvider).isEmpty
                    ? '/profile/intro'
                    : '/profile',
              ),
            ),
```

`AppMenuDrawer.build` 已是 `ConsumerWidget.build(BuildContext, WidgetRef ref)`，`ref` 在作用域内。`_navigate` 本身不变（仍 `pop + push`）。

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/shared/widgets/app_menu_drawer_profile_route_test.dart`
Expected: PASS

- [ ] **Step 5: 运行 analyze**

Run: `flutter analyze lib/shared/widgets/app_menu_drawer.dart`
Expected: 无新增 warning/error

- [ ] **Step 6: 提交**

```bash
git add lib/shared/widgets/app_menu_drawer.dart test/shared/widgets/app_menu_drawer_profile_route_test.dart
git commit -m "fix(drawer): 空 profile 点我的档案直接进引导页，避免双层栈回退"
```

---

## Task 3: 点踩内联输入框组件 inline_dislike_feedback

**Files:**
- Create: `lib/features/chat/widgets/inline_dislike_feedback.dart`
- Test: `test/features/chat/widgets/inline_dislike_feedback_test.dart`

**Interfaces:**
- Produces: `InlineDislikeFeedback` widget，构造参数 `{required ValueChanged<String> onSubmit, required VoidCallback onCollapse, bool submitting}`；内部 TextField + 「提交」FilledButton.tonal（onSubmit 调用，传入 trim 后文本）+ 「收起」TextButton（onCollapse）。

- [ ] **Step 1: 写失败测试**

新建 `test/features/chat/widgets/inline_dislike_feedback_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/chat/widgets/inline_dislike_feedback.dart';

void main() {
  testWidgets('提交时回调传入 trim 后文本', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineDislikeFeedback(
            onSubmit: (text) => submitted = text,
            onCollapse: () {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '  说得不清楚  ');
    await tester.tap(find.text('提交'));
    expect(submitted, '说得不清楚');
  });

  testWidgets('收起触发 onCollapse', (tester) async {
    var collapsed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineDislikeFeedback(
            onSubmit: (_) {},
            onCollapse: () => collapsed = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('收起'));
    expect(collapsed, isTrue);
  });

  testWidgets('submitting 时提交按钮禁用并显示加载', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineDislikeFeedback(
            onSubmit: (_) {},
            onCollapse: () {},
            submitting: true,
          ),
        ),
      ),
    );
    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/chat/widgets/inline_dislike_feedback_test.dart`
Expected: FAIL（`InlineDislikeFeedback` 未定义，编译失败）

- [ ] **Step 3: 实现 InlineDislikeFeedback**

新建 `lib/features/chat/widgets/inline_dislike_feedback.dart`：

```dart
import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';

/// 点踩后气泡下内联展开的反馈输入框：可选补充文字 + 提交/收起。
class InlineDislikeFeedback extends StatefulWidget {
  const InlineDislikeFeedback({
    super.key,
    required this.onSubmit,
    required this.onCollapse,
    this.submitting = false,
  });

  final ValueChanged<String> onSubmit;
  final VoidCallback onCollapse;
  final bool submitting;

  @override
  State<InlineDislikeFeedback> createState() => _InlineDislikeFeedbackState();
}

class _InlineDislikeFeedbackState extends State<InlineDislikeFeedback> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '告诉我们要怎么改进（可选）',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonal(
                onPressed: widget.submitting
                    ? null
                    : () {
                        Haptics.light();
                        widget.onSubmit(_controller.text.trim());
                      },
                child: widget.submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('提交'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  Haptics.light();
                  widget.onCollapse();
                },
                child: const Text('收起'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/chat/widgets/inline_dislike_feedback_test.dart`
Expected: PASS

- [ ] **Step 5: 运行 analyze**

Run: `flutter analyze lib/features/chat/widgets/inline_dislike_feedback.dart`
Expected: 无新增 warning/error

- [ ] **Step 6: 提交**

```bash
git add lib/features/chat/widgets/inline_dislike_feedback.dart test/features/chat/widgets/inline_dislike_feedback_test.dart
git commit -m "feat(chat): 点踩内联反馈输入框组件"
```

---

## Task 4: 长按导师卡片反馈 sheet

**Files:**
- Create: `lib/features/chat/widgets/recommendation_feedback_sheet.dart`
- Test: `test/features/chat/widgets/recommendation_feedback_sheet_test.dart`

**Interfaces:**
- Produces: `Future<void> showRecommendationFeedbackSheet({required BuildContext context, required String professorName})` 返回 `(String reason, String? note)` 或 null（取消）。reason ∈ {'推荐不准','信息不准确'}。

- [ ] **Step 1: 写失败测试**

新建 `test/features/chat/widgets/recommendation_feedback_sheet_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/chat/widgets/recommendation_feedback_sheet.dart';

void main() {
  testWidgets('选推荐不准+补充说明，提交返回正确结果', (tester) async {
    (String, String?)? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showRecommendationFeedbackSheet(
                    context: context,
                    professorName: '张三',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('推荐不准'));
    await tester.enterText(find.byType(TextField), '方向对不上');
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();
    expect(result?.$1, '推荐不准');
    expect(result?.$2, '方向对不上');
  });

  testWidgets('未选理由时提交按钮禁用', (tester) async {
    (String, String?)? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showRecommendationFeedbackSheet(
                    context: context,
                    professorName: '张三',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull);
    expect(result, isNull);
  });

  testWidgets('点信息不准确单独提交，note 为空', (tester) async {
    (String, String?)? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showRecommendationFeedbackSheet(
                    context: context,
                    professorName: '张三',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('信息不准确'));
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();
    expect(result?.$1, '信息不准确');
    expect(result?.$2, isNull);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/chat/widgets/recommendation_feedback_sheet_test.dart`
Expected: FAIL（`showRecommendationFeedbackSheet` 未定义）

- [ ] **Step 3: 实现 showRecommendationFeedbackSheet**

新建 `lib/features/chat/widgets/recommendation_feedback_sheet.dart`：

```dart
import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/ui/app_bottom_sheet.dart';

/// 长按导师卡片反馈弹层：预设「推荐不准」「信息不准确」单选 + 可选补充说明。
///
/// 返回 (reason, note?)；用户取消返回 null。
Future<(String, String?)?> showRecommendationFeedbackSheet({
  required BuildContext context,
  required String professorName,
}) async {
  return showAppBottomSheet<(String, String?)?>(
    context: context,
    builder: (ctx) => _RecommendationFeedbackSheet(professorName: professorName),
  );
}

class _RecommendationFeedbackSheet extends StatefulWidget {
  const _RecommendationFeedbackSheet({required this.professorName});

  final String professorName;

  @override
  State<_RecommendationFeedbackSheet> createState() =>
      _RecommendationFeedbackSheetState();
}

class _RecommendationFeedbackSheetState
    extends State<_RecommendationFeedbackSheet> {
  String? _reason;
  final TextEditingController _note = TextEditingController();

  static const _reasons = <String>['推荐不准', '信息不准确'];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _canSubmit => _reason != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('反馈「$professorName」的推荐',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _reasons)
                ChoiceChip(
                  label: Text(r),
                  selected: _reason == r,
                  onSelected: (_) {
                    Haptics.selection();
                    setState(() => _reason = _reason == r ? null : r);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '补充说明（可选）',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _canSubmit
                ? () {
                    Haptics.medium();
                    final note = _note.text.trim();
                    Navigator.of(context).pop((_reason!, note.isEmpty ? null : note));
                  }
                : null,
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/chat/widgets/recommendation_feedback_sheet_test.dart`
Expected: PASS

> 若 `showAppBottomSheet` 签名与上面 `showAppBottomSheet<T>(context, builder)` 不符，先读 [lib/core/ui/app_bottom_sheet.dart](../../lib/core/ui/app_bottom_sheet.dart) 确认签名，按实际签名调整调用（本 Task 在失败时据此修正）。

- [ ] **Step 5: 运行 analyze**

Run: `flutter analyze lib/features/chat/widgets/recommendation_feedback_sheet.dart`
Expected: 无新增 warning/error

- [ ] **Step 6: 提交**

```bash
git add lib/features/chat/widgets/recommendation_feedback_sheet.dart test/features/chat/widgets/recommendation_feedback_sheet_test.dart
git commit -m "feat(chat): 导师卡片长按反馈 sheet 组件"
```

---

## Task 5: SwipeRecommendationCard 加 onLongPress

**Files:**
- Modify: `lib/shared/widgets/swipe_recommendation_card.dart`
- Test: `test/shared/widgets/swipe_recommendation_card_test.dart`

**Interfaces:**
- Produces: `SwipeRecommendationCard` 新增可选 `VoidCallback? onLongPress`；长按触发，不干扰 onTap（整体）与 onFavoritePressed。

- [ ] **Step 1: 写失败测试 — 长按触发回调且不触发 onTap**

在 `test/shared/widgets/swipe_recommendation_card_test.dart` 的 `main()` 内追加：

```dart
  testWidgets('长按触发 onLongPress 且不触发 onTap', (t) async {
    var tapped = false;
    var longPressed = false;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeRecommendationCard(
            data: _data(RecommendationKind.mentor),
            onTap: () => tapped = true,
            onLongPress: () => longPressed = true,
          ),
        ),
      ),
    );
    await t.longPress(find.text('标题'));
    await t.pump();
    expect(longPressed, isTrue);
    expect(tapped, isFalse);
  });
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/shared/widgets/swipe_recommendation_card_test.dart --plain-name "长按触发 onLongPress 且不触发 onTap"`
Expected: FAIL（`onLongPress` 参数不存在，编译失败）

- [ ] **Step 3: 给 SwipeRecommendationCard 加 onLongPress 并用手势协调**

在 `lib/shared/widgets/swipe_recommendation_card.dart` 的 `SwipeRecommendationCard` 构造加参数（在 `onOpenUrlPressed` 之后）：

```dart
    this.onOpenUrlPressed,
    this.onLongPress,
```

并加字段（在 `final VoidCallback? onOpenUrlPressed;` 之后）：

```dart
  final VoidCallback? onLongPress;
```

把 `BentoTile(onTap: widget.onTap, ...)` 外层包一层 `GestureDetector`，处理长按；tap 仍交给 BentoTile 自身 onTap（避免重复）。把：

```dart
        final card = BentoTile(
          onTap: widget.onTap,
          padding: EdgeInsets.zero,
          border: Border.all(color: theme.colorScheme.outline),
          child: Padding(
```

改为：

```dart
        final inner = BentoTile(
          onTap: widget.onTap,
          padding: EdgeInsets.zero,
          border: Border.all(color: theme.colorScheme.outline),
          child: Padding(
```

然后在 `LayoutBuilder` 的 `builder` 末尾，把：

```dart
        if (constraints.hasBoundedHeight) return card;
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        return SizedBox(
          height: 250 + (textScale - 1).clamp(0, 1) * 54,
          child: card,
        );
```

改为：

```dart
        final card = widget.onLongPress == null
            ? inner
            : GestureDetector(
                onLongPress: () {
                  Haptics.light();
                  widget.onLongPress!();
                },
                child: inner,
              );
        if (constraints.hasBoundedHeight) return card;
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        return SizedBox(
          height: 250 + (textScale - 1).clamp(0, 1) * 54,
          child: card,
        );
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/shared/widgets/swipe_recommendation_card_test.dart`
Expected: PASS（含原有 3 个 + 新增长按）

- [ ] **Step 5: 运行 analyze**

Run: `flutter analyze lib/shared/widgets/swipe_recommendation_card.dart`
Expected: 无新增 warning/error

- [ ] **Step 6: 提交**

```bash
git add lib/shared/widgets/swipe_recommendation_card.dart test/shared/widgets/swipe_recommendation_card_test.dart
git commit -m "feat(card): SwipeRecommendationCard 支持长按回调"
```

---

## Task 6: RecommendationCarousel 透传 onLongPress + 上下文

**Files:**
- Modify: `lib/features/chat/widgets/recommendation_carousel.dart`
- Test: `test/features/chat/widgets/recommendation_carousel_test.dart`

**Interfaces:**
- Consumes: `SwipeRecommendationCard.onLongPress`（Task 5）、`Recommendation`。
- Produces: `RecommendationCarousel` 新增可选 `void Function(Recommendation r)? onReportRecommendation`；点击卡片整体 onTap 不变，长按卡片调 `onReportRecommendation(r)`。

- [ ] **Step 1: 写失败测试 — onReportRecommendation 收到对应导师**

先读现有 `test/features/chat/widgets/recommendation_carousel_test.dart` 顶部 import 与 `_rec` 构造模式，在其 `main()` 内追加（import 区补 `Recommendation`/`MatchLevel` 若缺）：

```dart
  testWidgets('长按卡片触发 onReportRecommendation 传入对应导师', (t) async {
    Recommendation? reported;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          favoriteRepositoryProvider.overrideWithValue(_FakeFavoriteRepo()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RecommendationCarousel(
              recommendations: const [_rec],
              onTap: (_) {},
              onReportRecommendation: (r) => reported = r,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.longPress(find.byType(SwipeRecommendationCard));
    await t.pump();
    expect(reported?.professorId, _rec.professorId);
  });
```

> 若该测试文件已有 `_FakeFavoriteRepo`/`_rec` 定义则直接复用；若命名不同，按文件实际命名引用。

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/chat/widgets/recommendation_carousel_test.dart --plain-name "长按卡片触发 onReportRecommendation"`
Expected: FAIL（`onReportRecommendation` 参数不存在）

- [ ] **Step 3: 给 RecommendationCarousel 加 onReportRecommendation 并注入卡片 onLongPress**

在 `lib/features/chat/widgets/recommendation_carousel.dart` 的 `RecommendationCarousel` 构造加参数（在 `onOpenHomepage` 之后）：

```dart
    this.onOpenHomepage,
    this.onReportRecommendation,
    this.height,
```

并加字段：

```dart
  final void Function(Recommendation recommendation)? onReportRecommendation;
```

在 `itemBuilder` 内 `SwipeRecommendationCard(...)` 加：

```dart
          onLongPress: onReportRecommendation == null
              ? null
              : () => onReportRecommendation!(r),
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/chat/widgets/recommendation_carousel_test.dart`
Expected: PASS

- [ ] **Step 5: 运行 analyze**

Run: `flutter analyze lib/features/chat/widgets/recommendation_carousel.dart`
Expected: 无新增 warning/error

- [ ] **Step 6: 提交**

```bash
git add lib/features/chat/widgets/recommendation_carousel.dart test/features/chat/widgets/recommendation_carousel_test.dart
git commit -m "feat(chat): RecommendationCarousel 透传长按反馈回调"
```

---

## Task 7: ChatMessageBubble 统一动作条 + 删孤立按钮 + 点踩内联

**Files:**
- Modify: `lib/features/chat/widgets/chat_message_bubble.dart`
- Test: `test/features/chat/chat_message_bubble_test.dart`

**Interfaces:**
- Consumes: `InlineDislikeFeedback`（Task 3）、`feedbackSubmitProvider`（由父注入回调）、`ChatMessageFeedback`。
- Produces: `ChatMessageBubble` 新增 `onDislikeFeedback(String messageId, String content)`；`_MessageActions` 转 StatefulWidget 持有点踩展开态；删除原 recommendation 类孤立感叹号按钮段（159-182 行）。

- [ ] **Step 1: 改失败测试 — 删旧 tooltip 断言，加新动作条断言**

在 `test/features/chat/chat_message_bubble_test.dart`：
1. 把现有测试「推荐卡片 done 态展示反馈按钮」（313-325 行）整体替换为：

```dart
  testWidgets('推荐卡片 done 态展示统一动作条（复制/赞/踩）无孤立感叹号', (tester) async {
    await _pump(
      tester,
      _msg(
        role: ChatRole.assistant,
        content: '推荐如下',
        status: ChatMessageStatus.done,
        kind: ChatMessageKind.recommendation,
      ),
    );
    expect(find.byTooltip('复制'), findsOneWidget);
    expect(find.byTooltip('有用'), findsOneWidget);
    expect(find.byTooltip('没用'), findsOneWidget);
    expect(find.byTooltip('反馈这条推荐'), findsNothing);
  });
```

2. 在 `main()` 末尾追加三个新测试（import 区补 `InlineDislikeFeedback`、`FeedbackContext`/`FeedbackType` 视调用需要）：

```dart
  testWidgets('点踩展开内联输入框并提交调 onDislikeFeedback', (tester) async {
    String? dislikedId;
    String? dislikedContent;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoriteRepositoryProvider.overrideWithValue(_FakeFavoriteRepo()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              message: _msg(
                role: ChatRole.assistant,
                content: '推荐如下',
                status: ChatMessageStatus.done,
              ),
              onTapRecommendation: (_) {},
              onFeedback: (_, _) {},
              onDislikeFeedback: (id, content) {
                dislikedId = id;
                dislikedContent = content;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('没用'));
    await tester.pump();
    expect(find.byType(InlineDislikeFeedback), findsOneWidget);
    await tester.enterText(find.byType(InlineDislikeFeedback), '推荐得不对');
    await tester.tap(find.text('提交'));
    expect(dislikedId, 'm_0');
    expect(dislikedContent, '推荐得不对');
  });

  testWidgets('赞调 onFeedback 置 like', (tester) async {
    String? fbId;
    ChatMessageFeedback? fb;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoriteRepositoryProvider.overrideWithValue(_FakeFavoriteRepo()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              message: _msg(
                role: ChatRole.assistant,
                content: '好的',
                status: ChatMessageStatus.done,
              ),
              onTapRecommendation: (_) {},
              onFeedback: (id, f) {
                fbId = id;
                fb = f;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('有用'));
    expect(fbId, 'm_0');
    expect(fb, ChatMessageFeedback.like);
  });

  testWidgets('再次点踩收起内联输入框', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoriteRepositoryProvider.overrideWithValue(_FakeFavoriteRepo()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              message: _msg(
                role: ChatRole.assistant,
                content: '推荐如下',
                status: ChatMessageStatus.done,
              ),
              onTapRecommendation: (_) {},
              onFeedback: (_, _) {},
              onDislikeFeedback: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('没用'));
    await tester.pump();
    expect(find.byType(InlineDislikeFeedback), findsOneWidget);
    await tester.tap(find.byTooltip('没用'));
    await tester.pump();
    expect(find.byType(InlineDislikeFeedback), findsNothing);
  });
```

> `_pump` 现有签名不含 `onDislikeFeedback`；上面新测试直接 `pumpWidget`，不经过 `_pump`，故无需改 `_pump`。

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/chat/chat_message_bubble_test.dart`
Expected: FAIL（`onDislikeFeedback` 参数不存在、`反馈这条推荐` 仍存在 → 第一个替换用例的 findsNothing 失败）

- [ ] **Step 3: 改 ChatMessageBubble — 删孤立按钮、加 onDislikeFeedback、_MessageActions 转 StatefulWidget**

在 `lib/features/chat/widgets/chat_message_bubble.dart`：

(a) 顶部 import 区追加：

```dart
import 'inline_dislike_feedback.dart';
```

(b) `ChatMessageBubble` 构造加参数（在 `onFeedback` 之后）：

```dart
    this.onFeedback,
    this.onDislikeFeedback,
    this.onRerouteHome,
```

并加字段：

```dart
  final void Function(String messageId, String content)? onDislikeFeedback;
```

(c) 删除 159-182 行整段（`if (message.kind == ChatMessageKind.recommendation && message.status == ChatMessageStatus.done)` 的孤立感叹号 Padding/_ActionButton push /feedback 段）。

(d) `_showActions` 改为：

```dart
  bool get _showActions =>
      message.role == ChatRole.assistant &&
      message.status == ChatMessageStatus.done &&
      (onRegenerate != null || onFeedback != null);
```

即删去 `message.kind == ChatMessageKind.conversation` 条件，让 recommendation 也走动作条。

(e) 把 `_MessageActions` 从 `StatelessWidget` 改为 `StatefulWidget`。构造加 `onDislikeFeedback`：

```dart
class _MessageActions extends StatefulWidget {
  const _MessageActions({
    required this.message,
    this.onRegenerate,
    this.onFeedback,
    this.onDislikeFeedback,
    this.onRetryRecommendation,
    this.feedbackSessionId,
    this.feedbackUserPrompt,
  });

  final ChatMessage message;
  final void Function(String messageId)? onRegenerate;
  final void Function(String messageId, ChatMessageFeedback feedback)?
  onFeedback;
  final void Function(String messageId, String content)? onDislikeFeedback;
  final void Function(String messageId)? onRetryRecommendation;
  final String? feedbackSessionId;
  final String? feedbackUserPrompt;

  @override
  State<_MessageActions> createState() => _MessageActionsState();
}

class _MessageActionsState extends State<_MessageActions> {
  bool _dislikeExpanded = false;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = AppColors.inkSoft;
    final activeColor = AppColors.indigo;
    final m = widget.message;
    final isRecommendation = m.kind == ChatMessageKind.recommendation;

    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                tooltip: '复制',
                icon: Icons.copy_outlined,
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: m.content));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('已复制')));
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('复制失败')));
                    }
                  }
                },
              ),
              if (isRecommendation && widget.onRetryRecommendation != null)
                _ActionButton(
                  tooltip: '重新生成推荐',
                  icon: Icons.refresh,
                  onPressed: () => widget.onRetryRecommendation!(m.id),
                )
              else if (!isRecommendation && widget.onRegenerate != null)
                _ActionButton(
                  tooltip: '重新生成',
                  icon: Icons.refresh,
                  onPressed: () => widget.onRegenerate!(m.id),
                ),
              _ActionButton(
                tooltip: '有用',
                icon: m.feedback == ChatMessageFeedback.like
                    ? Icons.thumb_up
                    : Icons.thumb_up_outlined,
                color: m.feedback == ChatMessageFeedback.like
                    ? activeColor
                    : inactiveColor,
                onPressed: widget.onFeedback == null
                    ? null
                    : () => widget.onFeedback!(
                          m.id,
                          m.feedback == ChatMessageFeedback.like
                              ? ChatMessageFeedback.none
                              : ChatMessageFeedback.like,
                        ),
              ),
              _ActionButton(
                tooltip: '没用',
                icon: m.feedback == ChatMessageFeedback.dislike
                    ? Icons.thumb_down
                    : Icons.thumb_down_outlined,
                color: m.feedback == ChatMessageFeedback.dislike
                    ? activeColor
                    : inactiveColor,
                onPressed: widget.onFeedback == null
                    ? null
                    : () {
                        final willDislike =
                            m.feedback != ChatMessageFeedback.dislike;
                        widget.onFeedback!(
                          m.id,
                          willDislike
                              ? ChatMessageFeedback.dislike
                              : ChatMessageFeedback.none,
                        );
                        setState(() => _dislikeExpanded = willDislike);
                      },
              ),
            ],
          ),
          if (_dislikeExpanded && widget.onDislikeFeedback != null)
            InlineDislikeFeedback(
              onSubmit: (content) =>
                  widget.onDislikeFeedback!(m.id, content),
              onCollapse: () => setState(() => _dislikeExpanded = false),
            ),
        ],
      ),
    );
  }
}
```

(f) 在 `build()` 内传 `onRetryRecommendation` 给 `_MessageActions`。把：

```dart
        if (_showActions)
          _MessageActions(
            message: message,
            onRegenerate: onRegenerate,
            onFeedback: onFeedback,
            feedbackSessionId: feedbackSessionId,
            feedbackUserPrompt: feedbackUserPrompt,
          ),
```

改为：

```dart
        if (_showActions)
          _MessageActions(
            message: message,
            onRegenerate: onRegenerate,
            onFeedback: onFeedback,
            onDislikeFeedback: onDislikeFeedback,
            onRetryRecommendation: onRetryRecommendation,
            feedbackSessionId: feedbackSessionId,
            feedbackUserPrompt: feedbackUserPrompt,
          ),
```

> 注意：原 `_MessageActions` 里的 `Icons.report_gmailerrorred_outlined` 反馈按钮整段已被新结构取代，不再跳 `/feedback`。`feedbackSessionId`/`feedbackUserPrompt` 现仅供未来扩展，若 analyze 报 unused field warning，可在 `ChatMessageBubble` 保留字段传入（已有用途：透传给 carousel 见 Task 8），无需删除。

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/chat/chat_message_bubble_test.dart`
Expected: PASS（含新 4 个 + 现有其余）

- [ ] **Step 5: 运行 analyze**

Run: `flutter analyze lib/features/chat/widgets/chat_message_bubble.dart`
Expected: 无新增 warning/error

- [ ] **Step 6: 提交**

```bash
git add lib/features/chat/widgets/chat_message_bubble.dart test/features/chat/chat_message_bubble_test.dart
git commit -m "feat(chat): 统一助手动作条 + 点踩内联反馈，删除孤立感叹号按钮"
```

---

## Task 8: ChatMessageBubble 透传长按上下文给 Carousel

**Files:**
- Modify: `lib/features/chat/widgets/chat_message_bubble.dart`
- Modify: `lib/features/chat/widgets/recommendation_carousel.dart`
- Test: `test/features/chat/chat_message_bubble_test.dart`（补长按卡片断言）

**Interfaces:**
- Consumes: `RecommendationCarousel.onReportRecommendation`（Task 6）。
- Produces: `ChatMessageBubble` 新增 `onReportRecommendation(Recommendation r, String reason, String? note)`；`RecommendationCarousel` 新增可选 `messageId`/`sessionId`/`prompt` 上下文（仅透传，本 Task 不强制用）。

- [ ] **Step 1: 写失败测试 — 长按卡片触发 onReportRecommendation**

在 `test/features/chat/chat_message_bubble_test.dart` 的 `main()` 末尾追加：

```dart
  testWidgets('长按推荐卡片触发 onReportRecommendation', (tester) async {
    Recommendation? reported;
    await _pump(
      tester,
      _msg(
        role: ChatRole.assistant,
        content: '相近导师如下',
        status: ChatMessageStatus.done,
        related: const [_rec],
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(SwipeRecommendationCard));
    await tester.pump();
    expect(reported?.professorId, _rec.professorId);
  });
```

> 此用例经 `_pump`，未注入 `onReportRecommendation`，故 `reported` 始终为 null，断言失败 → 需在实现中默认行为不报错；本 Task 仅验证「长按不会崩、长按不误触 onTap」。改为：把 `expect(reported?.professorId, ...)` 改为 `expect(find.byType(SwipeRecommendationCard), findsOneWidget)`（长按后卡片仍在）。若需验证回调，另写一个直接 `pumpWidget` 注入 `onReportRecommendation` 的用例：

```dart
  testWidgets('注入 onReportRecommendation 后长按回调', (tester) async {
    Recommendation? reported;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoriteRepositoryProvider.overrideWithValue(_FakeFavoriteRepo()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              message: _msg(
                role: ChatRole.assistant,
                content: '相近导师如下',
                status: ChatMessageStatus.done,
                related: const [_rec],
              ),
              onTapRecommendation: (_) {},
              onReportRecommendation: (r, _, _) => reported = r,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(SwipeRecommendationCard));
    await tester.pump();
    expect(reported?.professorId, _rec.professorId);
  });
```

> 注意：长按后 sheet 会弹出（showAppBottomSheet），`pumpAndSettle` 会等动画结束；测试里只 `pump()` 不 settle，避免阻塞。sheet 内容在 Task 9 由 ChatPage 接线后真正调用，本 Task bubble 只透传 raw 回调。

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/chat/chat_message_bubble_test.dart --plain-name "注入 onReportRecommendation 后长按回调"`
Expected: FAIL（`onReportRecommendation` 参数不存在）

- [ ] **Step 3: ChatMessageBubble 加 onReportRecommendation，透传给 Carousel**

在 `lib/features/chat/widgets/chat_message_bubble.dart`：

(a) `ChatMessageBubble` 构造加参数（在 `onOpenHomepage` 之后）：

```dart
    this.onOpenHomepage,
    this.onReportRecommendation,
```

并加字段：

```dart
  final void Function(Recommendation recommendation, String reason, String? note)?
  onReportRecommendation;
```

(b) `RecommendationCarousel(...)` 调用（138-147 行）加 `onReportRecommendation`：

```dart
          RecommendationCarousel(
            key: ValueKey('recommendations-${message.id}'),
            recommendations: message.relatedRecommendations,
            onTap: onTapRecommendation,
            onOpenHomepage: onOpenHomepage,
            onReportRecommendation: onReportRecommendation == null
                ? null
                : (r) async {
                    final res = await showRecommendationFeedbackSheet(
                      context: context,
                      professorName: r.name,
                    );
                    if (res == null) return;
                    onReportRecommendation!(r, res.$1, res.$2);
                  },
          ),
```

并在 import 区追加：

```dart
import 'recommendation_feedback_sheet.dart';
```

> 这样长按卡片在 bubble 层就弹 sheet 并回调；ChatPage（Task 9）只需提供 `onReportRecommendation` 提交逻辑，不再自己弹 sheet。

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/chat/chat_message_bubble_test.dart --plain-name "注入 onReportRecommendation 后长按回调"`
Expected: PASS（长按 → sheet 弹出 → 测试里 sheet 因未注入提交动作，`pump()` 不 settle 即断言回调已调）

> 若测试因 sheet 动画/`showAppBottomSheet` 阻塞而无法过，改为：在测试里 `await tester.longPress(...)` 后 `await tester.pump()`（不 settle），断言回调已触发——回调在 sheet 弹出前由 bubble 透传？需确认顺序：上面实现是「长按 → 立即弹 sheet → 用户选理由 → 提交回调」。因此单次长按不会立即触发 `onReportRecommendation`，需在 sheet 里选理由+提交。修正测试：长按后 `pumpAndSettle` 让 sheet 出现，点「推荐不准」+「提交」，再断言回调。改测试为：

```dart
    await tester.longPress(find.byType(SwipeRecommendationCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('推荐不准'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();
    expect(reported?.professorId, _rec.professorId);
```

- [ ] **Step 5: 运行该测试与全 bubble 测试**

Run: `flutter test test/features/chat/chat_message_bubble_test.dart`
Expected: PASS

- [ ] **Step 6: 运行 analyze**

Run: `flutter analyze lib/features/chat/widgets/chat_message_bubble.dart lib/features/chat/widgets/recommendation_carousel.dart`
Expected: 无新增 warning/error

- [ ] **Step 7: 提交**

```bash
git add lib/features/chat/widgets/chat_message_bubble.dart test/features/chat/chat_message_bubble_test.dart
git commit -m "feat(chat): ChatMessageBubble 长按卡片弹反馈 sheet 透传回调"
```

---

## Task 9: ChatPage 接线 onDislikeFeedback + onReportRecommendation

**Files:**
- Modify: `lib/features/chat/pages/chat_page.dart`
- Test: `test/features/chat/chat_page_test.dart`（补提交反馈断言，若现有结构便于注入）

**Interfaces:**
- Consumes: `feedbackSubmitProvider.submit`、`FeedbackType`、`FeedbackContext`、`ChatMessageBubble.onDislikeFeedback`、`onReportRecommendation`。
- Produces: ChatPage 将赞/踩沿用 `setFeedback`；点踩提交与长按提交走 `feedbackSubmitProvider`，成功 SnackBar「感谢反馈」、失败「反馈提交失败,请稍后重试」。

- [ ] **Step 1: 写失败测试 — 点踩提交触发 feedbackSubmitProvider**

读 `test/features/chat/chat_page_test.dart` 顶部现有 harness 与 `feedbackRepositoryProvider` override 模式。在 `main()` 内追加（命名按文件实际 harness 调整；若 harness 不便注入，改为 widget 测试直接 pump ChatPage 并 override `feedbackRepositoryProvider`）：

```dart
  testWidgets('点踩后提交内联反馈调用 feedbackRepository.submit', (tester) async {
    final submitted = <Feedback>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedbackRepositoryProvider.overrideWithValue(_RecordingFeedbackRepo(submitted)),
          // 其余 chat 依赖按现有 chat_page_test harness override
        ],
        child: const MaterialApp(home: ChatPage()),
      ),
    );
    // 触发一次助手回复（用现有 harness 的 send 方式或预置 state）
    // ... 按 harness 实际方式产出一条 assistant done 消息
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('没用'));
    await tester.pump();
    await tester.enterText(find.byType(InlineDislikeFeedback), '推荐得不对');
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();
    expect(submitted, isNotEmpty);
    expect(submitted.last.type, FeedbackType.other);
    expect(submitted.last.content, '推荐得不对');
  });
```

> `_RecordingFeedbackRepo` 与 chat 依赖 override 仿照文件现有 fake；若 chat_page_test 不易注入助手消息，改在 `chat_message_bubble_test.dart` 已验证的回调层加一个 `feedbackSubmitProvider` 集成测试（pump `ProviderScope` + `feedbackRepositoryProvider.override` + `ChatMessageBubble` 注入 `onDislikeFeedback` 调用 `feedbackSubmitProvider.submit`）——但这需要先把 ChatPage 的回调实现抽成可测函数。优先实现后再决定测试落点。

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/chat/chat_page_test.dart --plain-name "点踩后提交内联反馈"`
Expected: FAIL（ChatPage 尚未注入 `onDislikeFeedback`，InlineDislikeFeedback 找不到或提交不触发 repository）

- [ ] **Step 3: ChatPage 注入回调**

在 `lib/features/chat/pages/chat_page.dart`：

(a) import 区追加：

```dart
import '../../../core/result/result.dart';
import '../../../domain/entities/feedback.dart';
import '../../feedback/providers/feedback_provider.dart';
```

（`FeedbackType`/`FeedbackContext` 经 `feedback.dart`；`Result` 视 guard 需要）

(b) 在 `build` 内 `ChatMessageBubble(...)` 调用（约 667-695 行）加：

```dart
                  onDislikeFeedback: (id, content) =>
                      _submitMessageFeedback(ref, id, content),
                  onReportRecommendation: (r, reason, note) =>
                      _submitRecommendationFeedback(ref, r, reason, note),
```

（保留现有 `onFeedback`/`onRetryRecommendation`/`onRegenerate`/`feedbackSessionId`/`feedbackUserPrompt`）

(c) 在 `_SchoNaviAppState`/ChatPage 的 State 类内加两个方法（`_provider` 为现有 chat provider 引用名，按文件实际名）：

```dart
  Future<void> _submitMessageFeedback(
    WidgetRef ref,
    String messageId,
    String content,
  ) async {
    final message = ref.read(_provider).messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => null as ChatMessage,
    );
    final type = message?.kind == ChatMessageKind.recommendation
        ? FeedbackType.recommendation
        : FeedbackType.other;
    final ctx = (FeedbackContext(
      messageId: messageId,
      sessionId: ref.read(_provider).sessionId,
      prompt: _userPromptForMessage(ref.read(_provider), 0),
    )).copyWith(
      appVersion: ref.read(appConfigProvider).appVersion,
      dataSourceMode: ref.read(appConfigProvider).dataSource.name,
    );
    final ok = await ref.read(feedbackSubmitProvider.notifier).submit(
          type: type,
          content: content.isEmpty ? '点踩反馈（无文字）' : content,
          context: ctx,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '感谢反馈' : '反馈提交失败,请稍后重试')),
    );
  }

  Future<void> _submitRecommendationFeedback(
    WidgetRef ref,
    Recommendation r,
    String reason,
    String? note,
  ) async {
    final ctx = FeedbackContext(
      professorId: r.professorId,
      messageId: null,
      sessionId: ref.read(_provider).sessionId,
      prompt: _userPromptForMessage(ref.read(_provider), 0),
    ).copyWith(
      appVersion: ref.read(appConfigProvider).appVersion,
      dataSourceMode: ref.read(appConfigProvider).dataSource.name,
    );
    final content = note == null || note.isEmpty ? reason : '$reason：$note';
    final ok = await ref.read(feedbackSubmitProvider.notifier).submit(
          type: FeedbackType.recommendation,
          content: content,
          context: ctx,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '感谢反馈' : '反馈提交失败,请稍后重试')),
    );
  }
```

> `_userPromptForMessage(state, index)` 取用户上一条提问；若该方法签名是 `_userPromptForMessageIndex(state, index)`（见 home_page 用法），按 chat_page 实际辅助方法名调用。`message?.kind` 比较需 `ChatMessage` import（已在该文件）。`orElse: () => null as ChatMessage` 不合法——改用 `indexWhere`：

```dart
    final messages = ref.read(_provider).messages;
    final i = messages.indexWhere((m) => m.id == messageId);
    final type = (i >= 0 && messages[i].kind == ChatMessageKind.recommendation)
        ? FeedbackType.recommendation
        : FeedbackType.other;
```

采用 `indexWhere` 版本，删去 `firstWhere` 行。

(d) import `Recommendation`、`ChatMessage`、`ChatMessageKind` 若文件未 import。

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/chat/chat_page_test.dart`
Expected: PASS（新用例 + 现有）

- [ ] **Step 5: 运行 analyze**

Run: `flutter analyze lib/features/chat/pages/chat_page.dart`
Expected: 无新增 warning/error

- [ ] **Step 6: 提交**

```bash
git add lib/features/chat/pages/chat_page.dart test/features/chat/chat_page_test.dart
git commit -m "feat(chat): ChatPage 接线点踩内联与卡片长按反馈提交"
```

---

## Task 10: HomePage 同步注入新回调

**Files:**
- Modify: `lib/features/home/pages/home_page.dart`
- Test: `test/features/home/...`（若有 home bubble 测试则同步）

**Interfaces:**
- Consumes: 同 Task 9 的提交逻辑（home 页也用 ChatMessageBubble，[home_page.dart:667-695](../../lib/features/home/pages/home_page.dart)）。
- Produces: home 页 ChatMessageBubble 注入 `onDislikeFeedback` 与 `onReportRecommendation`，行为与 chat 页一致。

- [ ] **Step 1: 写失败测试（若 home 有 bubble 测试）**

读 `test/features/home/` 是否有覆盖 ChatMessageBubble 的 widget 测试。若有，补一个「点踩提交」断言；若无，跳过测试仅改实现（在 Step 4 用 analyze + 手动验证）。

- [ ] **Step 2: 运行测试验证失败（若有）**

Run: 视测试存在而定
Expected: FAIL

- [ ] **Step 3: home_page ChatMessageBubble 加回调**

在 `lib/features/home/pages/home_page.dart` 的 `ChatMessageBubble(...)`（667-695 行）加：

```dart
                  onDislikeFeedback: (id, content) =>
                      _submitMessageFeedback(ref, id, content),
                  onReportRecommendation: (r, reason, note) =>
                      _submitRecommendationFeedback(ref, r, reason, note),
```

并把 Task 9 的 `_submitMessageFeedback`/`_submitRecommendationFeedback` 复制到 home_page 的 State（`_provider` 改为 home 页 chat provider 引用名，`_userPromptForMessageIndex` 用 home 现有方法名）。import `feedback.dart`/`feedback_provider.dart`/`Recommendation`/`ChatMessageKind`。

- [ ] **Step 4: 运行 analyze**

Run: `flutter analyze lib/features/home/pages/home_page.dart`
Expected: 无新增 warning/error

- [ ] **Step 5: 运行相关测试**

Run: `flutter test test/features/home/`（若存在）
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add lib/features/home/pages/home_page.dart
git commit -m "feat(home): 首页对话气泡同步接入点踩与长按反馈"
```

---

## Task 11: 全量回归与上机验证

**Files:** 无代码改动，仅验证。

- [ ] **Step 1: 针对性测试全跑**

Run:
```bash
flutter test test/features/profile/profile_page_test.dart test/shared/widgets/app_menu_drawer_profile_route_test.dart test/features/chat/widgets/ test/shared/widgets/swipe_recommendation_card_test.dart test/features/chat/chat_message_bubble_test.dart test/features/chat/chat_page_test.dart
```
Expected: 全 PASS

- [ ] **Step 2: flutter analyze**

Run: `flutter analyze`
Expected: 无新增 issue

- [ ] **Step 3: 上机验证问题 1**

启动 app（冷启动，清 `seenOnboarding`/profile）：
1. 进首页 → 抽屉 → 我的档案 → 出现引导页。
2. 点引导页左上角回退 → **一次** 回到首页（不再停在引导页）。
3. 非空 profile 进档案 → 直接显示档案页，无引导页。

- [ ] **Step 4: 上机验证问题 2**

1. 对话页 AI 回复下方有 复制/赞/踩 小图标，无外框感叹号。
2. 点踩 → 气泡下展开输入框；输入并提交 → SnackBar「感谢反馈」，输入框收起。
3. 长按导师推荐卡片 → 弹「推荐不准/信息不准确」+ 补充说明 → 提交 → SnackBar「感谢反馈」。

- [ ] **Step 5: 记录验证结果**

在回复中如实报告：哪些通过、哪些无法本地验证（如无设备则明说）。

> 全量 `flutter test` 因 Drift 测试 hang（既有问题）不在必跑范围。

---

## 自检（plan self-review）

1. **Spec 覆盖：**
   - 问题 1 抽屉单点决策 → Task 2；ProfilePage 哨兵 → Task 1。✓
   - 问题 2 删孤立按钮 → Task 7(c)；统一动作条 → Task 7(d-e)；点踩内联 → Task 3+7+9；卡片长按 sheet → Task 4+5+6+8+9。✓
   - home 页同步 → Task 10。✓
2. **占位符扫描：** Task 9 有 `orElse: () => null as ChatMessage` 已在 Step 3 内修正为 `indexWhere`；其余无 TBD/TODO。✓
3. **类型一致性：** `onDislikeFeedback(String, String)` 在 Task 7/9/10 一致；`onReportRecommendation(Recommendation, String, String?)` 在 Task 8/9/10 一致；`showRecommendationFeedbackSheet` 返回 `(String, String?)?` 在 Task 4/8 一致。✓

---

## 执行交接

Plan complete and saved to `docs/superpowers/plans/2026-07-02-routing-and-feedback.md`. Two execution options:

**1. Subagent-Driven (recommended)** — 每 Task 派 fresh subagent，Task 间我 review，迭代快。
**2. Inline Execution** — 在本 session 用 executing-plans 批量执行带 checkpoint。

Which approach?
