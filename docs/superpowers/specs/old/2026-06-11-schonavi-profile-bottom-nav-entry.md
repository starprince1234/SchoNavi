# SchoNavi 设计 · Profile 底部导航栏入口 & 引导流程改进

- 版本：v1（2026-06-11）
- 关系：建立在 `2026-06-11-schonavi-profile-personalization-design.md`（Profile UI 已完整实现）之上，**仅改进入口位置与触发逻辑**。
- 改动范围：仅涉及导航结构与页面跳转逻辑，不改动已实现的 atoms/molecules/organisms/pages。

---

## 0. 用户故事

| #   | 角色   | 故事                                   | 设计回应                                                                                                                         |
| --- | ------ | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| 1   | 开发者 | 代码可维护性更高，组件原子化           | 新增 `ProfileIntroPage` 复用 `BentoTile`、`AnimatedEntrance`、`Haptics` 等既有原子组件；不引入任何新原子                         |
| 2   | 用户   | UI 精致打磨，拒绝原生素材拼凑感        | 严格执行 Bento 设计系统：`ColorScheme` 语义色、`surfaceContainerLowest` 卡片、`AnimatedEntrance` 错峰入场、haptics 全链路        |
| 3   | 用户   | 允许收集个人信息用于解析，换取更准推荐 | 引导说明页明确展示「精准推荐 / 智能套磁 / 匹配分析」三大价值；隐私声明诚实透明——「你的资料将用于个性化推荐、智能套磁与匹配分析」 |

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
2. **隐私协议前置同意**：用户首次使用个人数据相关功能前，必须先阅读并同意隐私协议；同意状态持久化
3. **首次引导经说明页进向导**：用户同意隐私协议后，第一次点击「我的」且档案为空时，展示**档案引导说明页**；用户点击「开始填写」后进入 `/profile/wizard`
4. **功能前置拦截**：用户在 Email/Match 页面点击核心操作按钮（生成/分析）时，若档案为空，先经隐私协议检查 → 进入**档案引导说明页**；用户确认后进入向导
5. **首页简化**：移除 AppBar 右上角 profile 图标，设置页保留「我的背景档案」作为冗余入口

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

### 3.2 隐私协议同意页

用户首次触发任何需要个人数据的功能前，必须先阅读并同意隐私协议。该页是**强制性**的——不同意则无法进入档案功能。

```
┌──────────────────────────────────────┐
│  ← 隐私协议                          │
│                                      │
│  我们尊重你的隐私。在使用个人档案    │
│  功能前，请阅读以下协议：            │
│                                      │
│  ┌────────────────────────────────┐ │
│  │ 📋 收集的信息                   │ │
│  │ 姓名、性别、学校、专业、GPA、   │ │
│  │ 研究兴趣、竞赛成果、科研成果    │ │
│  │                                │ │
│  │ 🎯 使用目的                     │ │
│  │ • 个性化导师推荐                │ │
│  │ • 生成 outreach 邮件            │ │
│  │ • 匹配度分析                    │ │
│  │                                │ │
│  │ 🔄 数据处理方式                 │ │
│  │ 本地存储 + 发送给大模型解析     │ │
│  │                                │ │
│  │ 🛡️ 你的权利                     │ │
│  │ 随时在「我的档案」修改或删除    │ │
│  └────────────────────────────────┘ │
│                                      │
│  [ ] 我已阅读并同意隐私协议          │
│                                      │
│  ┌────────────────────────────────┐ │
│  │         同意并继续              │ │
│  └────────────────────────────────┘ │
│                                      │
│           不同意，返回               │
│                                      │
└──────────────────────────────────────┘
```

- **页面标题**：「隐私协议」，带返回箭头
- **协议内容区**：可滚动的 `BentoTile` 卡片，包含 4 个区块（收集信息 / 使用目的 / 处理方式 / 用户权利）
- **Checkbox**：`CheckboxListTile` — 「我已阅读并同意隐私协议」
- **主按钮**：「同意并继续」— 仅在 checkbox 勾选后 `enabled = true`
- **次按钮**：「不同意，返回」— `Navigator.pop(context)`

**Bento 设计规范**：

- 页面 `Scaffold` + `AppBar(title: Text('隐私协议'))`
- 协议内容区使用 `BentoTile`，`surfaceContainerLowest`
- 各区块标题使用 `titleSmall` + `primary` 颜色
- Checkbox 使用 `ListTileTheme` 适配 Bento 风格
- 按钮区底部 `SafeArea` + `padding: EdgeInsets.all(16)`

**持久化**：

- SharedPreferences key: `privacy_agreed`
- 类型：`bool`
- 写入时机：用户点击「同意并继续」
- 读取时机：每次进入 Profile 相关功能前

### 3.3 档案引导说明页

当用户**已同意隐私协议**，且**首次触发档案填写**（点击「我的」tab、或在 Email/Match 被拦截）时，展示说明页：

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
- **隐私声明**：`Icons.shield_outlined` — 「你的资料将用于个性化推荐、智能套磁与匹配分析」
- **主按钮**：「开始填写（约 1 分钟）」→ `context.push('/profile/wizard')`
- **次按钮**：「以后再说」→ `Navigator.pop(context)`（返回触发页面）

**Bento 设计规范**：

- 页面背景使用 `Theme.of(context).colorScheme.surface`
- 3 个价值点卡片使用 `BentoTile`，`color: scheme.surfaceContainerLowest`，圆角 `16`
- 卡片内 icon 使用 `ColorScheme.primary` 容器底色
- 标题使用 `textTheme.headlineSmall`
- 正文使用 `textTheme.bodyMedium` + `ColorScheme.onSurfaceVariant`
- 按钮使用 `FilledButton`（主）+ `TextButton`（次）
- 整体使用 `ListView` + `padding: EdgeInsets.all(24)`，卡片间 `SizedBox(height: 12)`
- 页面入场使用 `AnimatedEntrance(index: 0)` 包裹内容体
- 按钮点击触发 `Haptics.light()` / `Haptics.medium()`

### 3.4 完整流程与状态映射

```
点击「我的」tab 或 Email/Match 操作
        │
        ▼
  ┌─────────────┐
  │ 档案为空？  │
  └──────┬──────┘
         │
    是 ──┼──► 检查隐私协议同意状态
    否   │      │
         │      ▼
         │   ┌─────────────┐
         │   │ 已同意？    │
         │   └──────┬──────┘
         │          │
         │     是 ──┼──► `/profile/intro`（说明页）
         │     否   │      │
         │          │      ▼ 点击「开始填写」
         │          │   `/profile/wizard`
         │          │
         │          └──► `/profile/privacy`（隐私协议页）
         │                 │
         │            同意 ─┼──► 写 `privacy_agreed=true`
         │                 │      自动进入 `/profile/intro`
         │            不同意┘
         │                 └──► `Navigator.pop`，回到原页面
         │
         └──► 正常展示 `/profile` 中心页
```

| 场景                    | 用户行为                         | 系统响应                                                        |
| ----------------------- | -------------------------------- | --------------------------------------------------------------- |
| 空档案 + 未同意隐私协议 | 点击底部「我的」                 | `context.push('/profile/privacy')`                              |
| 空档案 + 未同意隐私协议 | 在隐私协议页点击「同意并继续」   | 写 `privacy_agreed=true`，然后 `context.push('/profile/intro')` |
| 空档案 + 未同意隐私协议 | 在隐私协议页点击「不同意，返回」 | `Navigator.pop(context)`                                        |
| 空档案 + 已同意隐私协议 | 点击底部「我的」                 | `context.push('/profile/intro')`                                |
| 空档案 + 已同意隐私协议 | 在说明页点击「开始填写」         | `context.push('/profile/wizard')`                               |
| 空档案 + 已同意隐私协议 | 在说明页点击「以后再说」         | 返回上一页                                                      |
| 有档案                  | 点击底部「我的」                 | 正常展示 `/profile` 中心页                                      |
| 空档案 + 未同意隐私协议 | 在 `/email` 点击「生成套磁邮件」 | `context.push('/profile/privacy')`                              |
| 空档案 + 已同意隐私协议 | 在 `/email` 点击「生成套磁邮件」 | `context.push('/profile/intro')`                                |
| 空档案 + 未同意隐私协议 | 在 `/match` 点击「开始分析」     | `context.push('/profile/privacy')`                              |
| 空档案 + 已同意隐私协议 | 在 `/match` 点击「开始分析」     | `context.push('/profile/intro')`                                |
| 有档案                  | 在 `/email`/`/match` 点击操作    | 正常执行原流程                                                  |

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

`profile_page.dart` 的 `build` 方法首行增加隐私协议检查：

```dart
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
```

> 使用 `addPostFrameCallback` 避免在 build 期间直接导航导致异常。

### 4.4 EmailPage / MatchPage 前置拦截

`email_page.dart`：

- `_generate()` 方法：若 `profileProvider` 为空，检查 `privacy_agreed`
  - 未同意 → `context.push('/profile/privacy')`
  - 已同意 → `context.push('/profile/intro')`
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

### 4.6 隐私协议同意页组件

新增 `lib/features/profile/pages/privacy_agreement_page.dart`：

- `PrivacyAgreementPage extends StatefulWidget`（需要管理 checkbox 状态）
- `Scaffold` + `AppBar(title: Text('隐私协议'))`
- 内容结构（从上至下）：
  1. `Padding(16)` + Text「我们尊重你的隐私。在使用个人档案功能前，请阅读以下协议：」`bodyMedium`
  2. `SizedBox(height: 16)`
  3. `BentoTile`（`surfaceContainerLowest`，可滚动 `SingleChildScrollView`）：
     - 4 个区块，每个区块：
       - 标题行：`Icons` + Text（`titleSmall` + `primary` 颜色）
       - 内容 Text（`bodyMedium` + `onSurfaceVariant`）
       - 区块间 `Divider(height: 24)`
     - 区块内容：
       1. `Icons.description_outlined` — 「收集的信息」— 姓名、性别、学校、专业、GPA、研究兴趣、竞赛成果、科研成果
       2. `Icons.track_changes_outlined` — 「使用目的」— 个性化导师推荐、生成 outreach 邮件、匹配度分析
       3. `Icons.sync_outlined` — 「数据处理方式」— 本地存储 + 发送给大模型解析
       4. `Icons.verified_user_outlined` — 「你的权利」— 随时在「我的档案」中修改或删除数据
  4. `SizedBox(height: 16)`
  5. `CheckboxListTile`：
     - `title: Text('我已阅读并同意隐私协议')`
     - `value: _agreed`（`setState` 管理）
     - `controlAffinity: ListTileControlAffinity.leading`
  6. `Spacer()`
  7. 底部 SafeArea：`FilledButton`「同意并继续」(`enabled: _agreed`) + `TextButton`「不同意，返回」
- 按钮点击：
  - 「同意并继续」→ `Haptics.medium()` → `store.setBool('privacy_agreed', true)` → `context.push('/profile/intro')`
  - 「不同意，返回」→ `Haptics.light()` → `Navigator.pop(context)`
- 路由：`/profile/privacy`，使用 `sharedAxisPage` 转场

### 4.7 档案引导说明页组件

新增 `lib/features/profile/pages/profile_intro_page.dart`：

- `ProfileIntroPage extends StatelessWidget`
- 无 AppBar，全屏沉浸式
- 内容结构（从上至下）：
  1. `SizedBox(height: 48)` 顶部留白
  2. 标题 Text「完善档案，让推荐更懂你」`headlineSmall`
  3. `SizedBox(height: 32)`
  4. 3 个 `BentoTile` 纵向排列（`surfaceContainerLowest` 背景，`AnimatedEntrance` 错峰 `index: 0/1/2`）：
     - 每个 tile 左侧 `CircleAvatar`（`primary` 容器色）+ icon
     - 右侧 Column：标题 `titleSmall` + 描述 `bodyMedium`（`onSurfaceVariant`）
  5. `SizedBox(height: 24)`
  6. 隐私声明行：`Icons.shield_outlined` + Text「你的资料将用于个性化推荐、智能套磁与匹配分析」`bodySmall`
  7. `Spacer()`
  8. 底部 SafeArea：`FilledButton`「开始填写（约 1 分钟）」+ `TextButton`「以后再说」
- 按钮点击 haptics：`Haptics.medium()`（主）/ `Haptics.light()`（次）
- 路由：`/profile/intro`，使用 `sharedAxisPage` 转场

---

## 5. 影响面

| 文件                                                     | 改动类型 | 说明                                   |
| -------------------------------------------------------- | -------- | -------------------------------------- |
| `lib/core/router/app_router.dart`                        | 改       | StatefulShellRoute 增加 Profile branch |
| `lib/shared/widgets/scaffold_with_bottom_nav.dart`       | 改       | 增加第 4 个 tab                        |
| `lib/features/profile/pages/profile_page.dart`           | 改       | 空档案时先检查隐私协议同意状态         |
| `lib/features/profile/pages/privacy_agreement_page.dart` | **新增** | 隐私协议同意页（Bento 风格）           |
| `lib/features/profile/pages/profile_intro_page.dart`     | **新增** | 档案引导说明页（Bento 风格）           |
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
- `privacy_agreement_page`：
  - checkbox 未勾选时「同意并继续」按钮 disabled
  - checkbox 勾选后按钮 enabled，点击后写 `privacy_agreed=true` 并导航到 `/profile/intro`
  - 「不同意，返回」点击后 `Navigator.pop`
- `profile_page`：
  - 空档案 + 未同意隐私协议 → 导航到 `/profile/privacy`
  - 空档案 + 已同意隐私协议 → 导航到 `/profile/intro`
- `profile_intro_page`：「开始填写」导航到 `/profile/wizard`，「以后再说」返回上一页
- `email_page`：
  - 空档案 + 未同意隐私协议 → 导航到 `/profile/privacy`
  - 空档案 + 已同意隐私协议 → 导航到 `/profile/intro`
- `match_page`：同上
- `home_page`：AppBar 仅保留 settings 图标
- `app_e2e_test`：底部导航 tab 数量从 3 更新为 4

---

## 7. Backlog / 不改动

- Profile 向导的 3 步内容、organisms、provider 逻辑——**完全不动**
- SettingsPage 内的「我的背景档案」列表项——**保留**（冗余入口无妨）
- Profile 完成度计算、AI 抽取、推荐注入——**完全不动**
