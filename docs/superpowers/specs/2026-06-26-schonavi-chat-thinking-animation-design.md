---
title: SchoNavi 对话思考动画（大脑脉动）设计
date: 2026-06-26
status: approved
---

# SchoNavi 对话思考动画（大脑脉动）设计

## 背景与动机

用户反馈：在推荐导师时，用户发送消息后到后台响应前的等待期间缺少一个
「thinking」动画（如 SVG 大脑 + 灰度渐变），体验上不如主流 ChatAI App。

调研发现两个缺口：

1. **推荐流程完全没有思考气泡**。[chat_provider.dart:129-172](../../../lib/features/chat/providers/chat_provider.dart#L129-L172)
   的 `send` 推荐分支：追加用户消息 → `classifying`（无气泡）→
   `recommending`（无气泡）→ 推荐结果返回后才追加助手消息。整个
   classifying + recommending 期间消息列表里没有任何「正在思考」占位，
   只有底部输入条的小转圈。这是用户感知「缺了 thinking 动画」的根因。
2. **流式追问有思考指示但很朴素**。[chat_message_bubble.dart:35-58](../../../lib/features/chat/widgets/chat_message_bubble.dart#L35-L58)
   在首个 token 到达前显示 `CircularProgressIndicator + "正在思考…"`，
   流式中改为 `生成中…`。普通转圈，缺乏品牌辨识度。

## 目标

- 统一所有「等后台」时刻的视觉：推荐流程（新增）+ 流式首个 token 前（替换）
  使用同一个大脑脉动动画。
- 大脑用 `CustomPaint` 手绘，依赖无关（不引入 flutter_svg），与项目现有矢量
  组件（[scho_navi_logo.dart](../../../lib/shared/widgets/scho_navi_logo.dart)、
  [radar_chart.dart](../../../lib/shared/widgets/radar_chart.dart)）风格一致。
- 品牌色 indigo→cyan 渐变填充，冷调玻璃拟态视觉语言内。
- 最小侵入：复用既有 `ChatMessageStatus.sending` 状态语义，不新增状态枚举。

## 非目标

- 不改 `生成中…`（流式已有文本后的指示）—— 那是另一个状态，保持现状。
- 不改输入条转圈（`ChatInputBar` 的 `CircularProgressIndicator`）——
  本次范围只覆盖聊天气泡内。
- 不改 `quickActions` chip 的加载态。
- 不引入粒子、环绕等复杂动效（脉动呼吸已足够，YAGNI）。

## 架构与组件

### 新增 `ThinkingIndicator` widget

文件：`lib/shared/widgets/thinking_indicator.dart`

对外暴露 `ThinkingIndicator`（StatefulWidget，`SingleTickerProviderStateMixin`）。
纯展示组件，不感知任何业务状态、不依赖 Riverpod。

| 单元 | 职责 | 依赖 |
|------|------|------|
| `ThinkingIndicator` | 对外加载气泡。`AnimatedBuilder` 驱动 `CustomPaint` 大脑 + 文字「正在思考…」的 scale/opacity 呼吸。只负责显示。 | `AppColors`、`_BrainPainter`、内部 `AnimationController` |
| `_BrainPainter` (CustomPainter) | 手绘大脑轮廓（两半球俯视剪影 + 沟回暗纹），填 `AppColors.brandGradient`（indigo→cyan 横向）。`shouldRepaint` 返回 `false`（笔触静态，脉动靠外层 transform）。 | `AppColors` |
| 内部 `AnimationController` | duration 1200ms，`repeat(reverse: true)`，curve `Curves.easeInOut`。驱动 scale 0.92↔1.08 + opacity 0.55↔1.0 双通道呼吸。 | Flutter animation |

**布局参数**（对齐现有思考气泡，替换时尺寸/位置零漂移）：

- 外层 `Align(centerLeft)` + `Padding(sym vertical 8, horizontal 4)`。
- `Row(mainAxisSize: min)`：大脑 `SizedBox(18×18)` + `SizedBox(width:8)` +
  `Text('正在思考…')`。
- 文字样式沿用默认 `bodyMedium`（不显式指定，跟现有思考气泡一致）。

**为什么独立 widget**：

- `chat_message_bubble.dart` 已 266 行，职责是「一条消息的渲染」。继续往里
  塞 100+ 行 CustomPaint 会让文件臃肿、难测。
- 独立 widget 后 `ChatMessageBubble` 思考分支只需 `return const
  ThinkingIndicator();`，既可单独 widget 测试，未来别处（首页加载等）可复用。
- 符合项目「shared/widgets 放可复用视觉组件」既有约定（同
  `shimmer_skeleton`、`loading_view`）。

### 大脑矢量绘制细节（`_BrainPainter`）

画布取正方形 `Size.square(min(w,h))`，记边长 `s`，全部按比例绘制。

1. **两半球剪影**：两条 `cubicTo` 拼出对称「两瓣大脑」剪影，左半球以
   `(0.50s, 0.50s)` 为中线镜像右半球。顶部略凸（y 从 0.18s 到 0.45s），
   底部圆润收口（y 到 0.82s）。整体宽高比约 0.92:1，像真实大脑俯视剪影。
   填充用 `AppColors.brandGradient`（indigo→cyan 横向）经
   `Paint..shader = brandGradient.createShader(bounds)`。
2. **沟回暗纹**：2~3 条 `quadraticBezierTo` 在两半球各画一道浅沟。
   `style = stroke`，`strokeWidth = s*0.035`，颜色 `Colors.white @ 35% alpha`。
   叠在渐变填充之上，只做暗纹，不喧宾夺主。
3. **顶部高光**：一抹 `Colors.white @ 18%` 半透明弧，`blendMode = srcOver`，
   模拟环境光折射，呼应 logo 的 `glassHighlight` 处理。
4. `shouldRepaint(_BrainPainter old) => false` —— 笔触静态，脉动全靠外层
   `Transform.scale` + `Opacity`。

### 脉动动画细节

- `AnimationController`：duration `1200ms`，`repeat(reverse: true)`，
  curve `Curves.easeInOut`。
- 双通道驱动 `AnimatedBuilder`：
  - `scale: 0.92 → 1.08`（`Transform.scale`，`alignment = 大脑中心`）
  - `opacity: 0.55 → 1.0`（作用于整个 `CustomPaint` + 文字）
- 18px 大脑脉动幅度过大会「跳」；0.92↔1.08 + opacity 双通道 = 「呼吸」而非
  「跳动」，观感接近 ChatGPT 那种克制的脉动。幅度参数是最易事后微调的项。
- 生命周期：`initState` 创建 controller + `repeat()`；`dispose` 释放。
  `SingleTickerProviderStateMixin` 即可（单 controller）。

## 接入点

### 接入点 1：`ChatMessageBubble` 思考分支（替换）

[chat_message_bubble.dart:35-58](../../../lib/features/chat/widgets/chat_message_bubble.dart#L35-L58)

现状：`isThinking` 时返回 `Row(CircularProgressIndicator + Text('正在思考…'))`。

改造：整段替换为 `return const ThinkingIndicator();`。

`isThinking` 判定不变：
```dart
final isThinking =
    message.status == ChatMessageStatus.sending ||
    (message.status == ChatMessageStatus.streaming &&
        message.content.isEmpty);
```

覆盖流式首个 token 前（`status == streaming && content.isEmpty`）+ `sending`
态。`生成中…`（有文本的 streaming）保持不变。

### 接入点 2：`ChatNotifier` 推荐分支追加思考占位

[chat_provider.dart:129-172](../../../lib/features/chat/providers/chat_provider.dart#L129-L172)

**当前流程**：
```
send → 追加用户消息 → classifying（无气泡）→ recommending（无气泡）→ 结果回来追加助手消息
```

**改造后**：
```
send → 追加用户消息 → recommending → 追加思考占位(status=sending, kind=recommendation)
     → 结果 Success → 用结果消息替换占位
     → 结果 Failure → 用 error 消息替换占位
```

实现：`send` 推荐分支在 `state = state.copyWith(activity:
ChatActivity.recommending)` 之后，生成占位 id 并追加占位消息，再调用
`_requestRecommendations(content, token: token, placeholderId: placeholderId)`。

`_requestRecommendations` 签名新增 `required String placeholderId` 参数：

- 成功时不再 `[..., ChatMessage(结果)]`，改为
  `state.messages.map((m) => m.id == placeholderId ? 结果消息 : m).toList()`。
- 失败时 `_appendRecommendationError` 同理改为「替换占位」而非「追加」。
  签名也接收 `placeholderId`。

### 接入点 3：`bootstrapRecommendations` 统一走占位

[chat_provider.dart:108-127](../../../lib/features/chat/providers/chat_provider.dart#L108-L127)

首页首轮：追加用户消息后，同样追加思考占位，再走改造后的
`_requestRecommendations(placeholderId:)`。体验统一（首页提交后立刻有思考气泡）。

### 接入点 4：`retryRecommendation` 统一走占位

[chat_provider.dart:174-194](../../../lib/features/chat/providers/chat_provider.dart#L174-L194)

现状：`sublist(0, assistantIndex)` 砍掉错误消息 → 重新拉推荐 → 追加。

改造：砍掉错误消息后**追加思考占位**（与 retry 的 user 消息成对），再走替换
路径。失败时占位换成新的 error 消息，可再次 retry。

## 状态机与竞态防护

**占位消息状态**：`status = sending`，`kind = recommendation`，
`relatedRecommendations = []`，`content = ''`。

**替换语义**：`_requestRecommendations` 成功/失败均用 `map((m) => m.id ==
placeholderId ? 新消息 : m)` 按 id 替换占位，不引入额外状态字段。

**竞态/过期 token**：占位消息受现有 `_isCurrent(token)` 保护，与现有逻辑一致 ——
过期请求不写 state，占位不会被旧请求的结果替换。不新增防护。竞态在实际使用中
不常见，沿用既有 token 机制即可。

## 测试策略

### `ThinkingIndicator` 单元/widget 测试（新建）

文件：`test/shared/widgets/thinking_indicator_test.dart`

1. **渲染断言**：`find.byType(CustomPaint)` 找到大脑画笔；
   `find.text('正在思考…')` 找到文案；`find.byType(CircularProgressIndicator)`
   找不到（确认换掉旧转圈）。
2. **生命周期**：动画 `repeat`，不能用 `pumpAndSettle`（会卡死）。改用
   `pump(Duration)` 固定时长后断言无异常。验证 controller 释放：
   `tester.dispose` 之后再 pump 不抛错。
3. **不依赖业务**：直接 `MaterialApp(home: Scaffold(body:
   ThinkingIndicator()))` pump，不需 ProviderScope，验证纯展示组件。

### `ChatMessageBubble` 测试改动

[chat_message_bubble_test.dart:129-141](../../../test/features/chat/chat_message_bubble_test.dart#L129-L141)
和
[chat_message_bubble_test.dart:190-202](../../../test/features/chat/chat_message_bubble_test.dart#L190-L202)

两处旧断言 `find.byType(CircularProgressIndicator), findsOneWidget` 改为
`find.byType(ThinkingIndicator), findsOneWidget`。文案 `'正在思考…'` 不变。

### `ChatNotifier` 测试改动/新增

文件：`test/features/chat/chat_provider_test.dart`

4. **推荐占位新增**：`send` 走推荐分支时，在 mock repository resolve 之前
   pump，断言 `state.messages.last.status == sending && kind == recommendation`
   （思考占位已入列）。
5. **成功替换**（关键）：mock 推荐返回成功后，断言 `state.messages.length == 2`
   （用户 + 1 条结果），**不是 3**。即占位被替换、不是追加。同时结果消息
   `relatedRecommendations` 非空、`status == done`。
6. **失败替换**：mock 推荐抛异常，断言最后一条是
   `status == error, kind == recommendation`，且 `messages.length == 2`
   （占位换成 error，不是再加一条）。
7. **bootstrap 占位**：同 #5 风格，首页首轮也断言占位→替换。
8. **retry 占位**：先造一个 error 推荐消息，调 `retryRecommendation`，pump
   中途断言思考占位出现，完成后断言被替换为成功消息。
9. **过期 token**（保留语义）：`send` 推荐中途 `start` 另一个会话（或 `stop`）
   使 token 失效，占位**不应**被旧请求的结果替换。复用现有 token 失效测试套路。

### 全量回归

`flutter test` 全绿是硬门槛（当前 397+ 测试）。新增约 5~7 个测试用例，改 2 处
旧断言。

## 实现顺序（writing-plans 阶段细化）

1. 新建 `ThinkingIndicator` + `_BrainPainter` + 测试，独立可跑。
2. 接入 `ChatMessageBubble` 思考分支，改 2 处旧测试断言。
3. 改造 `ChatNotifier`：`_requestRecommendations(placeholderId:)` + send /
   bootstrap / retry 三处占位路径。
4. 新增/调整 `ChatNotifier` 测试。
5. `flutter test` 全量回归。

## 开放参数（事后微调，不阻塞实现）

- 大脑脉动幅度 `scale 0.92↔1.08`、`opacity 0.55↔1.0`：实际跑起来觉得幅度
  不够或过大，调这两个数值即可，不影响架构。
- 动画 duration `1200ms`：偏快/偏慢可调。
