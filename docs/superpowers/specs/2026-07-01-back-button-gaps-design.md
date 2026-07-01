# 返回键缺口修补设计

- 日期：2026-07-01
- 分支：iter4rc2
- 范围：只补缺口 —— chat / profile_intro / profile_wizard / competition_detail 四页的返回交互缺口，不改动已有正常 AppBar 的页面。

## 背景与问题

移动端系统返回键（Android 物理返回 / iOS 边缘滑动）是核心交互。盘查路由表后，四类页面存在返回交互缺口：

| 页面 | 缺口 |
|---|---|
| `lib/features/chat/pages/chat_page.dart` | 已有顶栏返回箭头，但返回时无「生成中拦截确认」；系统返回手势同样无拦截，可能误触丢失正在生成的对话轮次。 |
| `lib/features/profile/pages/profile_intro_page.dart` | 无 `AppBar`，仅底部「以后再说」TextButton 调 `context.pop()`；顶栏无返回键。 |
| `lib/features/profile/pages/profile_wizard_page.dart` | `WizardScaffold` 的 `AppBar` 默认 `automaticallyImplyLeading=true`，顶栏返回箭头会直接 pop 整页，step 1/2 时点它不会回退上一步（只有底部「上一步」按钮才是 step-back）。系统返回手势同样直接退出。 |
| `lib/features/competition_recommendation/pages/competition_detail_page.dart` | loading / error / 空态用 `appBar: AppBar()`（空 AppBar），返回键其实会显示，但视觉空荡且与主态标题不一致。 |

不在本次范围内（确认无缺口）：home（首页本就不该返回）、onboarding（首启引导，有「跳过」）、settings / profile / favorites / history / recommendation / competition-recommendation / professor / email / compare / match / feedback / privacy_agreement / preparation_plans / preparation_plan_detail / preparation_plan_form（均已有标准 `AppBar`，返回键正常）。

## 总体策略

每页就地修补，不引入新组件、不引入新路由层、不引入新状态管理依赖。所有「返回」入口（顶栏返回箭头 + 系统返回手势）收口到同一个页面级回调，确保两条路径行为一致。

统一返回语义：

- 默认页：`context.pop()`（go_router）。
- chat：生成中拦截确认，否则 pop。
- wizard：step 0 pop 整页，step > 0 回退上一步。
- intro：加 AppBar，pop 整页。

技术选型：

- 统一用 `PopScope`（Flutter 3.16+），不用已废弃的 `WillPopScope`。
- 项目 Flutter 版本 3.44.1（Dart 3.12.1），`onPopInvokedWithResult` 新签名可用。
- `Haptics.light()` 沿用现有触感约定。
- 不新增 provider、不新增路由、不新增 widget 文件。

## 逐页改动

### 2.1 chat_page —— PopScope 统一拦截

在 `lib/features/chat/pages/chat_page.dart` 第 158 行 `Scaffold` 外层包一个 `PopScope`：

```dart
return PopScope(
  canPop: !_isStreaming(state),
  onPopInvokedWithResult: (didPop, _) async {
    if (didPop) return;
    final shouldExit = await _confirmExit(context, ref);
    if (shouldExit && context.mounted) context.pop();
  },
  child: Scaffold(...),
);
```

要点：

- **判断生成中**：`state.activity == ChatActivity.streaming`（与第 299 行 `canStop` 逻辑同源）。
- **拦截确认对话框** `_confirmExit`：`AlertDialog`，标题「正在生成中」，内容「当前对话正在生成，离开会中断本轮。要离开吗？」，按钮「继续生成」(取消) / 「离开」(确认)。确认后调 `ref.read(_provider.notifier).stop()` 再 `context.pop()`；`stop()` 是 fire-and-forget，不阻塞返回。
- **对话框生命周期守卫**：`showDialog` 调用前用 `context.mounted` 守卫；用户取消返回 `false`，不 pop。
- **顶栏返回箭头**：第 351-355 行（普通页 `FloatingTopButton`）与第 323-327 行（fork 页 `ProfessorAnchorBar.leading`）两处 `onPressed: () => context.pop()` 改为 `onPressed: () => _handleBack(context, ref)`，复用同一拦截逻辑。
  - 注意：`PopScope` 的 `onPopInvokedWithResult` 不会被普通 `context.pop()` 调用触发，所以按钮回调必须手动走 `_confirmExit` 流程，否则按钮返回会绕过拦截。
- **非生成态**：`canPop=true`，系统返回手势直接放行，零摩擦。
- **fork 追问页**：第 307-337 行 fork 页返回箭头同样改为 `_handleBack`，与主分支返回逻辑一致；`trailing` 的「重新生成」按钮不变。

### 2.2 profile_intro_page —— 加 AppBar

`lib/features/profile/pages/profile_intro_page.dart` 第 16 行 `Scaffold` 加 `appBar`：

```dart
return Scaffold(
  appBar: AppBar(title: const Text('完善档案')),
  body: SafeArea(child: ...),
);
```

- 顶栏自动出返回箭头（`automaticallyImplyLeading` 默认 true），pop 整页。
- 底部「以后再说」按钮**保留** —— 它是「跳过本次填写」的语义，与返回不冲突，且提供非顶栏退出路径，对单手操作友好。

### 2.3 profile_wizard_page —— 顶栏箭头联动 step-back

`WizardScaffold` 已有 `onBack` 参数（`onBack: _step == 0 ? null : _back`，见 `profile_wizard_page.dart` 第 79 行），但当前 `AppBar` 没用它 —— 默认 leading 直接 pop 整页。改动是让 `WizardScaffold`（`lib/features/profile/widgets/wizard_scaffold.dart` 第 31 行 `AppBar`）的 leading 透传已有的 `onBack`：

```dart
appBar: AppBar(
  title: const Text('完善个人档案'),
  leading: onBack == null
      ? null  // step 0：默认 BackButton，pop 整页
      : IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '上一步',
          onPressed: () { Haptics.light(); onBack!(); },
        ),
),
```

并在 `WizardScaffold` 外层包 `PopScope`。`WizardScaffold` 新增两个参数 `canPop` 与 `onSystemBack`，由 `ProfileWizardPage` 传入：

- `ProfileWizardPage` 计算 `canPop = _step == 0`，`onSystemBack = _step == 0 ? null : _back`。
- `_step == 0`：`canPop=true`，放行。
- `_step > 0`：`canPop=false`，`onPopInvokedWithResult` 调 `onSystemBack!()`（step-back）。

这样顶栏箭头、底部「上一步」、系统返回手势三者**行为一致**。`WizardScaffold` 的 `onBack` 语义不变（仍代表「step-back」），只是顶栏 leading 现在也走它。

### 2.4 competition_detail_page —— 空态 AppBar 补标题

`lib/features/competition_recommendation/pages/competition_detail_page.dart` 第 33 / 49 / 53 行三处 `appBar: AppBar()` 改为 `appBar: AppBar(title: const Text('竞赛详情'))`。返回键本就显示，只补标题以对齐主态。

## 数据流、边界与错误处理

| 拦截点 | 状态来源 | 边界处理 |
|---|---|---|
| chat 返回拦截 | `ChatState.activity == ChatActivity.streaming` | state 为空 / loading 态时 `activity != streaming` → `canPop=true` 放行；`_confirmExit` 在 state 不可用时也走非拦截分支 |
| wizard step-back | `_step`（本地 int） | `_step` 初始即 0，无空态；`onBack` 仅在 `_step > 0` 时传入，step 0 走默认 BackButton |
| intro / 竞赛空态 | 无状态依赖 | 纯 AppBar 改动 |

不引入新依赖：不用 `WillPopScope`（已废弃），统一用 `PopScope`；不新增 provider / 路由 / widget 文件；`Haptics.light()` 沿用现有约定。

风险：

- **PopScope 与 go_router 兼容**：go_router 的 `context.pop()` 触发 Navigator pop，`PopScope` 能正常拦截；社区已验证用法。低风险。
- **`onPopInvokedWithResult` 签名**：Flutter 3.22+ 新签名带 `result` 参数；项目 3.44.1 支持，用新签名。
- **chat 返回箭头两处分支**：fork 页（anchor bar）与普通页（floating button）路径不同，改动需同时覆盖，避免遗漏。

## 测试与验证

### 单元 / widget 测试（最小相关测试优先）

**chat_page**（已有 widget 测试基础）：

- 流式生成中触发系统返回 → 弹确认对话框；点「继续生成」→ 不 pop、对话框关闭、流式继续。
- 流式生成中点确认「离开」→ 调用 `stop()` + `context.pop()`。
- 非生成态触发返回 → 直接 pop，无对话框。

**profile_wizard_page**：

- step 0 点顶栏返回 → pop 整页。
- step 1/2 点顶栏返回 → `_step` 递减、不 pop。
- step 1/2 触发系统返回手势（`PopScope`）→ 同样 step-back。

**profile_intro_page**：现有测试若有「以后再说」按钮断言则保留；新增顶栏返回箭头存在性断言。

**competition_detail_page**：loading / error / 空态断言 AppBar 标题为「竞赛详情」。

### 手测清单（UI 改动必须手测）

1. chat 生成中按系统返回 → 确认框出现 → 取消 → 会话仍在；确认 → 回上一页且流式停止。
2. chat 非生成态返回 → 秒回，无确认框。
3. chat fork 追问页生成中返回 → 同主分支行为。
4. intro 页顶栏返回箭头 → 回上一页；底部「以后再说」仍可用。
5. wizard step 1 顶栏箭头 → 回到 step 0；step 0 顶栏箭头 → 退出 wizard。
6. wizard step 1 系统返回手势 → 回到 step 0（与顶栏一致）。
7. 竞赛详情 loading / 错误 / 空态 → 顶栏有「竞赛详情」标题 + 返回键。
8. Android 物理返回键 + iOS 边缘滑动均验证（两条平台路径）。

### 静态检查

```bash
flutter analyze
dart format --set-exit-if-changed lib test
flutter test test/features/chat/...
flutter test test/features/profile/...
flutter test test/features/competition_recommendation/...
```

### 不做的事

- 不跑 `realdata` 后端测试（与本次无关）。
- 不改其他页面的 AppBar（范围已锁定「只补缺口」）。
- 不引入 golden test（项目无 golden 基建，手测覆盖视觉）。

### 完成判定

单元 / widget 测试全绿、手测清单全过、`flutter analyze` 无新增 error/warning → 视为完成。若本地无法起设备 / 模拟器，明确说明。
