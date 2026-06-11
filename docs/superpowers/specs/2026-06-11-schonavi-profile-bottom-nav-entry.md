# SchoNavi 设计 · Profile 底部导航栏入口 & 引导流程改进

- 版本：v1（2026-06-11）
- 关系：建立在 `2026-06-11-schonavi-profile-personalization-design.md`（Profile UI 已完整实现）之上，**仅改进入口位置与触发逻辑**。
- 改动范围：仅涉及导航结构与页面跳转逻辑，不改动已实现的 atoms/molecules/organisms/pages。

---

## 1. 问题

当前实现（Profile UI Plan 完成后）：

- Profile 入口在 **HomePage AppBar 右上角**（`Icons.person_outline`）+ SettingsPage 内列表项
- 新用户引导是 **JIT（Just-In-Time）触发**：仅在点击「开始推荐」时弹 `ProfilePromptSheet`，可跳过
- 这导致：
  1. 用户不易发现 Profile 功能（右上角图标隐蔽）
  2. 用户点击「生成套磁邮件」/「匹配分析」时，空档案会弹 sheet，体验割裂

---

## 2. 目标

1. **Profile 入口显性化**：移至底部导航栏作为第 4 个常驻 tab「我的」
2. **首次引导经说明页进向导**：用户第一次点击「我的」且档案为空时，先展示**档案引导说明页**，告知用户完善档案的 3 大价值；用户点击「开始填写」后进入 `/profile/wizard`
3. **功能前置拦截**：用户在 Email/Match 页面点击核心操作按钮（生成/分析）时，若档案为空，先进入**档案引导说明页**；用户确认后进入向导
4. **首页简化**：移除 AppBar 右上角 profile 图标，设置页保留「我的背景档案」作为冗余入口

---

## 3. 交互流程

### 3.1 底部导航栏

```
┌─────────────────────────────────────────┐
│  🔍 首页    🔖 收藏    🕐 历史    👤 我的  │
└─────────────────────────────────────────┘
```

- 选中态图标：`Icons.person`
- 未选中态图标：`Icons.person_outline`
- 标签：「我的」

### 3.2 档案引导说明页

当用户**首次触发档案填写**（点击「我的」tab、或在 Email/Match 被拦截）时，不直接跳进向导，而是先展示一个轻量说明页，解释「为什么要填」：

```
┌──────────────────────────────────────┐
│                                      │
│      🎓 完善档案，让推荐更懂你       │
│                                      │
│   ┌──────┐  ┌──────┐  ┌──────┐    │
│   │ 📊   │  │ ✉️   │  │ 🔬   │    │
│   │精准  │  │智能  │  │匹配  │    │
│   │推荐  │  │套磁  │  │分析  │    │
│   └──────┘  └──────┘  └──────┘    │
│                                      │
│   结合你的成绩和背景                 │
│   匹配最合适的导师                   │
│                                      │
│   ─────────────────────────────────  │
│                                      │
│   💡 资料仅保存在本机，不上传服务器    │
│                                      │
│   ┌────────────────────────────────┐ │
│   │      开始填写（约 1 分钟）      │ │
│   └────────────────────────────────┘ │
│                                      │
│           以后再说                   │
│                                      │
└──────────────────────────────────────┘
```

- **标题**：「完善档案，让推荐更懂你」
- **3 个价值点**（横向排列或纵向列表）：
  1. `Icons.trending_up` — **精准推荐** — 结合你的成绩和背景，匹配最合适的导师
  2. `Icons.auto_fix_high` — **智能套磁** — 自动生成个性化的 outreach 邮件
  3. `Icons.psychology` — **匹配分析** — 评估你与导师研究方向的契合度
- **隐私声明**：`Icons.shield_outlined` — 「资料仅保存在本机，不上传服务器」
- **主按钮**：「开始填写（约 1 分钟）」→ `context.push('/profile/wizard')`
- **次按钮**：「以后再说」→ `Navigator.pop(context)`（返回触发页面）

### 3.3 状态映射

| 场景   | 用户行为                         | 系统响应                          |
| ------ | -------------------------------- | --------------------------------- |
| 空档案 | 点击底部「我的」                 | `context.push('/profile/intro')`  |
| 空档案 | 在说明页点击「开始填写」         | `context.push('/profile/wizard')` |
| 空档案 | 在说明页点击「以后再说」         | 返回上一页（留在当前 tab/页面）   |
| 有档案 | 点击底部「我的」                 | 正常展示 `/profile` 中心页        |
| 空档案 | 在 `/email` 点击「生成套磁邮件」 | `context.push('/profile/intro')`  |
| 空档案 | 在 `/match` 点击「开始分析」     | `context.push('/profile/intro')`  |
| 有档案 | 在 `/email`/`/match` 点击操作    | 正常执行原流程                    |

**注意**：从向导完成后（点击「完成」），自动回到 `/profile`（不是底部导航的某个 tab，而是作为独立页面在栈上）。用户可返回继续原流程。

---

## 4. 技术规格

### 4.1 路由调整

`app_router.dart` 的 `StatefulShellRoute.indexedStack` 增加第 4 个 `StatefulShellBranch`：

```dart
StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/profile',
      pageBuilder: (_, state) => sharedAxisPage(
        state: state,
        child: const ProfilePage(),
      ),
    ),
  ],
),
```

**约束**：`/profile` 同时在 `StatefulShellRoute` 内（底部导航目的地）和外部路由表中存在。外部路由表中的 `/profile` 保留用于非底部导航的直接跳转（如从向导完成后的导航）。

> go_router 支持同一路径在 shell 内外共存——外部路由优先匹配非 shell 上下文，shell 内匹配底部导航。经测试无冲突。

### 4.2 底部导航栏组件

`scaffold_with_bottom_nav.dart`：

- `_scaling` map 扩展为 4 个键：`{0: false, 1: false, 2: false, 3: false}`
- `destinations` 列表追加第 4 个 `NavigationDestination`

### 4.3 ProfilePage 空档案重定向

`profile_page.dart` 的 `build` 方法首行增加：

```dart
if (profile.isEmpty) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) context.push('/profile/wizard');
  });
}
```

> 使用 `addPostFrameCallback` 避免在 build 期间直接导航导致异常。

### 4.4 EmailPage / MatchPage 前置拦截

`email_page.dart`：

- `_generate()` 方法：若 `profileProvider` 为空，直接 `context.push('/profile/wizard')`，不再弹 sheet
- 移除 `profile_prompt_sheet.dart` 的 import（不再使用）

`match_page.dart`：

- `_analyze()` 方法：同上逻辑

### 4.5 HomePage 清理

`home_page.dart`：

- 移除 AppBar `actions` 中的 profile `IconButton`
- 保留 settings 图标
- `_submit()` 中的 JIT profile prompt 逻辑**移除**——引导不再在推荐时触发，改在「我的」tab 和 email/match 中触发
- 移除 `profile_prompt_sheet.dart` 的 import
- 移除 `promptDismissedKey` 常量

---

## 5. 影响面

| 文件                                                     | 改动类型 | 说明                                   |
| -------------------------------------------------------- | -------- | -------------------------------------- |
| `lib/core/router/app_router.dart`                        | 改       | StatefulShellRoute 增加 Profile branch |
| `lib/shared/widgets/scaffold_with_bottom_nav.dart`       | 改       | 增加第 4 个 tab                        |
| `lib/features/profile/pages/profile_page.dart`           | 改       | 空档案时自动跳向导                     |
| `lib/features/email/pages/email_page.dart`               | 改       | 空档案直接跳向导，去 sheet             |
| `lib/features/match/pages/match_page.dart`               | 改       | 空档案直接跳向导，去 sheet             |
| `lib/features/home/pages/home_page.dart`                 | 改       | 移除右上角入口，去 JIT 触发            |
| `lib/features/profile/widgets/profile_prompt_sheet.dart` | **可删** | 不再使用                               |
| `test/features/home/home_page_test.dart`                 | 改       | 移除 profile 图标测试                  |
| `test/features/home/home_prompt_test.dart`               | **可删** | JIT prompt 测试不再适用                |
| `test/features/email/email_page_test.dart`               | 改       | 调整空档案导航断言                     |
| `test/features/match/`                                   | 改       | 调整空档案导航断言                     |
| `test/app_e2e_test.dart`                                 | 改       | 底部导航 now 4 tabs                    |

---

## 6. 测试要点

- `scaffold_with_bottom_nav`：4 个 tab 切换正常，haptics 触发正确
- `profile_page`：空档案时自动导航到 `/profile/wizard`
- `email_page`：空档案时点击生成按钮导航到 `/profile/wizard`
- `match_page`：空档案时点击分析按钮导航到 `/profile/wizard`
- `home_page`：AppBar 仅保留 settings 图标
- `app_e2e_test`：底部导航 tab 数量从 3 更新为 4

---

## 7. Backlog / 不改动

- Profile 向导的 3 步内容、organisms、provider 逻辑——**完全不动**
- SettingsPage 内的「我的背景档案」列表项——**保留**（冗余入口无妨）
- Profile 完成度计算、AI 抽取、推荐注入——**完全不动**
