# 引导页回退栈修复 + 反馈交互重设计

日期：2026-07-02
分支：iter4rc3

## 背景与问题

### 问题 1：冷启动 → 汉堡菜单 → 我的档案 → 引导页，回退要按两次

复现：冷启动（`seenOnboarding=true`、profile 为空）→ 抽屉点「我的档案」→ 出现「完善档案」引导页（`/profile/intro`）→ 点引导页左上角回退 → 仍停在引导页，需再按一次才退回。

根因：

1. 抽屉 [app_menu_drawer.dart:113-117](../../lib/shared/widgets/app_menu_drawer.dart) 用 `context.push('/profile')`，栈变为 `/home → /profile`。
2. [profile_page.dart:28-39](../../lib/features/profile/pages/profile_page.dart) 在 `profile.isEmpty` 时，于 `build()` 内用 `addPostFrameCallback` 调 `context.push('/profile/intro')`，栈变为 `/home → /profile → /profile/intro`。
3. [profile_provider.dart:9-20](../../lib/features/profile/providers/profile_provider.dart) 的 `ProfileController.build()` 同步返回 `repo.load()`（空），`LocalProfileRepository.refresh()` 仅 `async => load()`（[local_profile_repository.dart:42](../../lib/data/local/local_profile_repository.dart)），空态不会改变。
4. 用户点回退 pop 掉 `/profile/intro` → 栈回到 `/home → /profile` → **ProfilePage 重建** → 又满足 `profile.isEmpty` → 又 postFrame push `/profile/intro`。回退后被再次拉回引导页，故需两次。

根因定性：把"空 profile 跳引导"的导航副作用放在 `build()` 里、且以 `profile.isEmpty` 为唯一判据、每次 rebuild 都执行；空态恒定，导致回退后必然重复 push。

### 问题 2：反馈按钮形态割裂

现状：

- 推荐类助手消息下方单独渲染一个**带外框感叹号**按钮 `Icons.report_gmailerrorred_outlined`，点击跳 `/feedback` 页（[chat_message_bubble.dart:159-182](../../lib/features/chat/widgets/chat_message_bubble.dart)）。
- 普通对话类助手消息已有 `_MessageActions`：复制 / 重新生成 / 赞 / 踩 / 反馈（同文件 225-335）。
- 导师推荐卡片（SwipeRecommendationCard）无长按反馈入口。

目标（ChatGPT/豆包式）：

1. AI 回复下方统一小图标条：复制、赞、踩；推荐类额外保留「重新生成推荐」。
2. 去掉孤立的外框感叹号按钮。
3. 点踩后在气泡下方**内联展开**输入框，提交具体反馈文字，不离开当前页。
4. 长按导师推荐卡片 → 弹出反馈菜单，预设「推荐不准」「信息不准确」。

## 设计决策（已与用户确认）

- 问题 1 修法：**方案 A 入口单点决策** + 哨兵防 rebuild 重复 push。
- 点踩输入形态：**气泡下内联展开输入框**。
- 卡片长按预设理由：**推荐不准、信息不准确**（不做"未收录/自由文本"）。
- 动作条覆盖：**统一一套**（conversation + recommendation 共用）。

## 问题 1 修复设计

### 入口单点决策

在抽屉层判断 profile 空态，直接进引导页，避免「先 push profile 再 push intro」的双层栈：

- `AppMenuDrawer._navigate(context, '/profile')` 改为读 `ref.read(profileProvider).isEmpty`：
  - 空 → `context.push('/profile/intro')`（栈 `/home → /profile/intro`，回退一次即回 home）。
  - 非空 → `context.push('/profile')`（原行为）。
- 抽屉是 ConsumerWidget，已能读 `profileProvider`。
- 隐私页同意后 [privacy_agreement_page.dart:28](../../lib/features/profile/pages/profile_privacy.dart) 已是 `context.push('/profile/intro')`，保持不变。

### 移除 build 副作用 + 一次性哨兵兜底

- 将 `ProfilePage` 由 `ConsumerWidget` 改为 `ConsumerStatefulWidget`。
- 删除 `build()` 内的 `addPostFrameCallback` push 段落。
- 在 `initState()` 内做一次性哨兵：若 `ref.read(profileProvider).isEmpty` 且未同意隐私（`privacy_agreed` false）→ push `/profile/privacy`；若空且已同意 → push `/profile/intro`。用实例字段 `_redirected = false` 保证一个 ProfilePage 实例只触发一次。
- 这样：从 `/profile/intro` 回退到 `/profile` 时，ProfilePage 实例**不重建**（GoRouter 恢复已实例化页面，initState 不再跑），不会重复 push。
- 主入口（抽屉）已直接进 intro，ProfilePage 的哨兵仅作其他入口（如深链、未来入口）的兜底。

### 回退语义（修复后）

- 抽屉进引导：`/home → /profile/intro` → 回退一次回 `/home`。✓
- 引导页「以后再说」`context.pop()` → 回 `/home`。✓
- 引导页「开始填写」`context.push('/profile/wizard')` → 向导完成 `context.go('/profile')`（[profile_wizard_page.dart:31](../../lib/features/profile/pages/profile_wizard_page.dart)），此时 profile 非空，正常显示档案。✓

### 影响文件

- [lib/shared/widgets/app_menu_drawer.dart](../../lib/shared/widgets/app_menu_drawer.dart)：`_navigate` 对 `/profile` 空态分流；`_ProfileHeader.onTap` 同步处理。
- [lib/features/profile/pages/profile_page.dart](../../lib/features/profile/pages/profile_page.dart)：转 `ConsumerStatefulWidget`，删 build 副作用，加 `initState` 哨兵。
- 测试：`test/features/profile/profile_page_test.dart`、新增/更新抽屉导航测试。

## 问题 2 反馈重设计

### 统一动作条 `_MessageActions`

- 覆盖条件改为：助手消息且 `status == done`（不再限定 `kind == conversation`），即 conversation + recommendation 共用。
- 图标条：复制（copy_outlined）、赞（thumb_up[_outlined]）、踩（thumb_down[_outlined]）；recommendation 类额外渲染「重新生成推荐」（refresh，调 `onRetryRecommendation`）。
- conversation 类保留「重新生成」（onRegenerate）。
- **删除** [chat_message_bubble.dart:159-182](../../lib/features/chat/widgets/chat_message_bubble.dart) 的孤立外框感叹号按钮段。
- 赞/踩沿用 `onFeedback(messageId, ChatMessageFeedback)` → `ChatNotifier.setFeedback`（[chat_provider.dart:381](../../lib/features/chat/providers/chat_provider.dart)）管道，不变。

### 点踩内联展开输入框

- `_MessageActions` 改为 `StatefulWidget`，持有 `_expanded`（踩后展开）、`_submitting`、`_submitted`。
- 点踩逻辑：
  - 调 `onFeedback(messageId, dislike)` 置踩态（高亮 thumb_down）。
  - 同时 `setState(() => _expanded = true)`，在动作条下方展开 `_InlineFeedbackInput`。
- `_InlineFeedbackInput`：单行/双行 TextField（占位「告诉我们要怎么改进（可选）」）+ 「提交」FilledButton.tonal + 「收起」TextButton。Haptics.light。
- 提交：调新增回调 `onDislikeFeedback(messageId, content)`，由 ChatPage 注入 → `feedbackSubmitProvider.submit`：
  - `type`：recommendation 类消息 → `FeedbackType.recommendation`；conversation 类 → `FeedbackType.other`。
  - `content`：用户输入；若为空则用「点踩反馈（无文字）」兜底，保证 ≥5 字（[feedback_page.dart:41-43](../../lib/features/feedback/pages/feedback_page.dart) 的最小长度约束是 FeedbackPage 的，提交层不强加，但 repository 可能校验——这里让 content 至少有兜底文案）。
  - `context`：`FeedbackContext(messageId, sessionId, prompt)`。
- 提交成功 → SnackBar「感谢反馈」+ 收起输入框 + 置 `_submitted`（隐藏输入框，保留踩态高亮）。失败 → SnackBar「反馈提交失败,请稍后重试」并保留输入框。
- 再次点踩（已踩）→ 切回 none 并收起输入框。

### 导师卡片长按反馈

- `SwipeRecommendationCard` 新增可选 `onLongPress` 回调；内部 `Listener`/`GestureDetector` 在长按时触发（与现有 onFavoritePressed 的 Listener 协调，避免手势冲突——长按用 `onLongPress`，点击/收藏保留）。
- `RecommendationCarousel` 新增可选 `onReportRecommendation(Recommendation r, String reason, String? note)`，透传给卡片 `onLongPress`。
- 长按弹层：复用 `showAppBottomSheet`，内容：
  - 标题「反馈这条推荐」。
  - 两个预设理由 ChoiceChip：「推荐不准」「信息不准确」（单选）。
  - 可选 TextField「补充说明（可选）」。
  - 「提交」FilledButton。
- 提交：`onReportRecommendation(r, reason, note)` → ChatPage 注入 → `feedbackSubmitProvider.submit`：
  - `type`：`FeedbackType.recommendation`。
  - `content`：`reason` +（note 非空）`：note`。
  - `context`：`FeedbackContext(professorId: r.professorId, messageId, sessionId, prompt)`。
- 成功 → SnackBar + 关闭 sheet。失败 → SnackBar 保留 sheet。
- `messageId/sessionId/prompt` 由 `ChatMessageBubble` 透传给 `RecommendationCarousel`（新增参数）。

### 数据流总览

```
赞/踩：bubble.onFeedback → ChatPage → ChatNotifier.setFeedback → persist（既有）
踩+文字：_MessageActions 展开 → onDislikeFeedback(msgId,content) → ChatPage
        → feedbackSubmitProvider.submit(type, content, ctx{msgId,sid,prompt})
卡片长按：SwipeRecommendationCard.onLongPress → RecommendationCarousel.onReportRecommendation(r,reason,note)
        → ChatPage → feedbackSubmitProvider.submit(recommendation, reason:note, ctx{profId,msgId,sid,prompt})
```

### 影响文件

- [lib/features/chat/widgets/chat_message_bubble.dart](../../lib/features/chat/widgets/chat_message_bubble.dart)：删孤立按钮；`_MessageActions` 转 StatefulWidget + 赞/踩/复制/重新生成 + 内联展开；新增 `onDislikeFeedback` 回调与 `_InlineFeedbackInput`；给 `RecommendationCarousel` 透传 messageId/sessionId/prompt。
- [lib/features/chat/widgets/recommendation_carousel.dart](../../lib/features/chat/widgets/recommendation_carousel.dart)：新增 `onReportRecommendation` + 上下文参数，传给卡片 `onLongPress`。
- [lib/shared/widgets/swipe_recommendation_card.dart](../../lib/shared/widgets/swipe_recommendation_card.dart)：新增 `onLongPress`，与现有点击/收藏手势协调。
- [lib/features/chat/pages/chat_page.dart](../../lib/features/chat/pages/chat_page.dart)：注入 `onDislikeFeedback`、`onReportRecommendation`，复用 `feedbackSubmitProvider`；透传 messageId/sessionId/prompt 给 bubble 与 carousel。
- [lib/features/home/pages/home_page.dart](../../lib/features/home/pages/home_page.dart)：home 页也用 ChatMessageBubble（[home_page.dart:690](../../lib/features/home/pages/home_page.dart)），同步注入新回调；竞赛首页若用 SwipeRecommendationCard 也需处理长按（可先空实现，仅对话场景启用）。
- 反馈弹层：新增 `lib/features/chat/widgets/recommendation_feedback_sheet.dart`（或内联于 carousel）。

### 不改动

- `FeedbackRepository` / `Feedback` / `FeedbackContext` / `feedbackSubmitProvider` 接口不变，复用既有提交链路。
- `ChatMessageFeedback` 枚举与 `ChatNotifier.setFeedback` 不变。
- `/feedback` 路由与 FeedbackPage 保留（抽屉「反馈」入口、其他场景仍用）。

## 测试

### 问题 1

- `test/features/profile/profile_page_test.dart`：空 profile 进入 ProfilePage 只触发一次引导 push；模拟 rebuild 不再重复 push。
- 抽屉导航测试：空 profile 点「我的档案」→ 栈为 `/home → /profile/intro`；非空 → `/home → /profile`。
- 回退用例：从 `/profile/intro` pop 一次回到 `/home`。

### 问题 2

- `test/features/chat/widgets/chat_message_bubble_test.dart`（新增/扩展）：
  - recommendation 类 done 消息渲染统一动作条（复制/赞/踩/重新生成推荐），无外框感叹号。
  - 点踩 → 展开内联输入框；提交 → 调 `onDislikeFeedback(msgId, content)`；再次点踩收起。
  - 赞/踩调 `onFeedback`。
- `test/shared/widgets/swipe_recommendation_card_test.dart`：长按触发 `onLongPress`，不干扰 onTap/onFavoritePressed。
- 反馈弹层测试：选择「推荐不准」+ 补充说明 → 提交调 `onReportRecommendation(r, reason, note)`。
- `feedbackSubmitProvider` 集成：提交带正确 type/context（messageId/professorId/sessionId）。

## 验证

- `flutter analyze`。
- 针对性 `flutter test`：profile_page、chat_message_bubble、swipe_recommendation_card、feedback_provider 相关。
- 上机：冷启动空 profile → 抽屉 → 我的档案 → 引导页回退一次回 home；点踩展开输入并提交；长按导师卡片弹层提交。
- 受 Drift 测试 hang 影响的全量 `flutter test` 不在本次必跑范围（既有问题）。

## 范围边界

- 不做：长按卡片「导师未收录」、自由文本预设项、反馈页改版、反馈历史展示、踩态服务端持久化扩展（仅沿用 setFeedback）。
- 不引入新状态管理/路由/HTTP 库。
- 不改 LLM 路径与 provider。
