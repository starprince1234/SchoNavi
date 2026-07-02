# 通知交互升级设计

- 日期：2026-07-02
- 分支：iter4rc3
- 目标：把现有「单条每日提醒通知」升级为对 Android 通知系统的完整使用——多通道、分组、每日摘要、动作按钮后台闭环、独立截止闹钟。让 AIGC 评委看到的是「完整的 Android 通知系统使用」而非「简单弹通知」。

## 背景与现状

当前实现（[ReminderScheduler.kt](android/app/src/main/kotlin/com/example/scho_navi/ReminderScheduler.kt)）：

- 单 `ReminderReceiver`，`AlarmManager` 在用户设定时刻（默认 20:00）触发一次
- 取 snapshot 中最紧急的 plan，发**一条**通知，content intent 跳详情页
- 单 `NotificationChannel`（`preparation_reminders`，IMPORTANCE_DEFAULT）
- 无动作按钮、无分组、无摘要总结
- snapshot schema v2：含 streak / preparedToday / plans[]（nextTaskTitle/DueDate、completed/total、phases）

## 设计决策（已确认）

1. **分组范围**：建两类真实来源——备赛任务（已有）+ 竞赛截止（新增 deadline-ahead 闹钟）。导师咨询仅建 channel 作为结构占位，本迭代无真实来源。
2. **动作交互**：三个按钮后台动作闭环——完成今日任务（MethodChannel → Flutter 持久化）、稍后提醒（1h 后重排闹钟）、查看计划（跳详情页）。
3. **每日摘要**：复用 20:00 闹钟，作为分组总结通知（`setGroupSummary`），不新增闹钟。
4. **截止提前点**：固定 7/3/0 天，当天 9:00 响铃。
5. **completeTask 反向通道返回值**：成功 `success(null)`、失败 `result.error(code, msg, null)`，与现有 `addDeadlineEvent`/`openNotificationSettings` 风格一致。

## §1 架构

### 通知通道（3 个）

| channel id | 名称 | importance | 用途 |
|---|---|---|---|
| `preparation_tasks` | 备赛任务 | DEFAULT | 每日 20:00 最紧急任务 + 每日摘要 |
| `competition_deadlines` | 竞赛截止 | HIGH | 截止前 7/3/0 天 9:00 |
| `mentor_consultations` | 导师咨询 | DEFAULT | 结构占位，本迭代无真实来源 |

> 说明：每日摘要与备赛任务复用同一 channel（`preparation_tasks`），因为两者主题一致且都在 20:00 触发；摘要作为该分组的 summary notification。

### Receiver 矩阵

| Receiver | 触发 | 职责 |
|---|---|---|
| `DailyReminderReceiver` | 20:00 闹钟（复用 `ReminderScheduler`） | 发「备赛任务」通知（最紧急任务，带 3 动作按钮）+「每日摘要」总结通知（`setGroupSummary`） |
| `DeadlineAlarmReceiver` | 截止前 7/3/0 天 9:00 独立闹钟 | 发「竞赛截止」通知（带「查看计划」按钮） |
| `ReminderActionReceiver` | 用户点通知动作按钮 | 完成 / 稍后 / 查看 三选一，后台执行 |
| `ReminderRescheduleReceiver` | BOOT / 时区 / 日期变更 | 重排 daily 闹钟 + 截止闹钟 |

### 截止闹钟来源

- 原生端**不重复算**调度逻辑；由 Flutter 端在 `syncSnapshot` 时计算「今天及之后应响的截止点」一并下发
- 新增 `DeadlineAlarmScheduler`（原生）：接收截止点列表，用 `AlarmManager` 排多个独立闹钟
- requestCode 唯一性：`planId.hashCode() * 10 + offsetIndex`（offsetIndex: 0=d-7, 1=d-3, 2=d），`FLAG_UPDATE_CURRENT` 保证覆盖

### 动作闭环

```
通知按钮 → ReminderActionReceiver
   ├─ COMPLETE → MethodChannel "completeTask" → Flutter 持久化 → 刷新 snapshot → 同步回原生
   ├─ SNOOZE   → AlarmManager 排 1h 后重发同 planId 的任务通知
   └─ VIEW     → PendingIntent → MainActivity → openRoute("/preparation-plans/{planId}")
```

## §2 数据流

### Snapshot schema 升级 v2 → v3

在 `PreparationReminderSnapshot` 增加 `digest` 与 `deadlineAlerts` 两个字段。**所有计算放 Flutter 端**，原生端只渲染。

**新增 `PreparationReminderDigest`**（每日摘要数据）：

```dart
class PreparationReminderDigest {
  final int remainingToday;          // 今日未完成任务数（跨所有 active 计划）
  final int upcomingDeadlines;       // 未来 30 天内截止的竞赛数
  final String? nearestDeadlineName; // 最近截止竞赛名
  final String? nearestDeadlineDay;  // 最近截止日 isoDay
}
```

**新增 `DeadlineAlert`**（截止闹钟点）：

```dart
class DeadlineAlert {
  final String planId;
  final String competitionName;
  final String alertIsoDay;    // 响铃日 = targetDate - 7/3/0
  final int daysBefore;        // 7 / 3 / 0
  final String deadlineIsoDay; // 实际截止日（展示用）
}
```

Snapshot 新增字段：

```dart
final PreparationReminderDigest digest;
final List<DeadlineAlert> deadlineAlerts;  // 仅 future，已按时间排序
```

`schemaVersion` → 3。

### 计算逻辑（Flutter `PreparationReminderBuilder`）

**`deadlineAlerts` 计算**：
- 对每个 active plan，以 `targetDate` 为锚生成 3 个点 `[d-7, d-3, d]`（9:00 响）
- 过滤掉 `alertIsoDay < today` 的
- 同一 plan 同一天只保留最近的一个提前点（如 d-3 已过、d 当天，只发 d）
- 按 `alertIsoDay` 升序

**`digest` 计算**：
- `remainingToday` = 所有 active plan 的 phases.tasks 中 `dueDate == today && !completed` 的计数
- `upcomingDeadlines` = active plans 中 `targetDate` 在 `[today, today+30d]` 的数量
- `nearestDeadlineName/Day` = active plans 中 `targetDate >= today` 的最早一个

### syncSnapshot 透传

`syncSnapshot` JSON 仍整体下发；原生 `ReminderStorage.loadSnapshot` 解析新字段：
1. `digest` 存内存缓存，供 `DailyReminderReceiver` 20:00 发摘要通知用
2. `deadlineAlerts` 传给 `DeadlineAlarmScheduler.apply()`，对每个 alert 排一个 9:00 闹钟（`alertIsoDay` 当天 9:00），旧截止闹钟全清后重排

### 同步时机

- 现有同步点不变（计划变更、任务完成、App 启动、daily reconcile）→ 自动带上新字段
- `completeTask` 动作完成后 → Flutter 端刷新 snapshot → `syncSnapshot` → 原生重排截止闹钟 + 更新 digest

## §3 文件改动清单

### 原生端（Kotlin）— 4 改 2 新

**改 [ReminderScheduler.kt](android/app/src/main/kotlin/com/example/scho_navi/ReminderScheduler.kt)**
- `pendingIntent`：requestCode 改为按 planId 区分（`planId.hashCode()`），支持多闹钟；`ACTION_NOTIFY` 拆成 daily 专用
- 新增 `DeadlineAlarmScheduler`（同文件或新文件）：`apply(alerts: List<DeadlineAlert>)` 批量排/取消 9:00 闹钟

**改 [ReminderStorage.kt](android/app/src/main/kotlin/com/example/scho_navi/ReminderStorage.kt)**
- 新增 `ReminderDigest`、`DeadlineAlert` 数据类
- `loadSnapshot` 解析 `digest`、`deadlineAlerts` 字段
- digest 存内存缓存（不持久化，每次 syncSnapshot 覆盖）

**改 `ReminderReceiver`（拆分）**
- 拆成 `DailyReminderReceiver`（发任务通知 + 摘要总结通知，带分组）
- 拆成 `DeadlineAlarmReceiver`（发截止通知，从 intent extras 取 planId/competitionName/daysBefore）
- 新增 `ReminderActionReceiver`：3 动作三选一
  - `COMPLETE` → `remindersChannel.invokeMethod("completeTask", planId)` + 取消该通知
  - `SNOOZE` → 重排 1h 后 AlarmManager（用 planId.hashCode() 做唯一 requestCode）
  - `VIEW` → 复用现有 openIntent 逻辑
- `ensureChannel` 注册 3 个 channel

**改 [MainActivity.kt](android/app/src/main/kotlin/com/example/scho_navi/MainActivity.kt)**
- `handleReminderCall` 新增 `"completeTask"` 分支：转发到 Flutter 端完成方法（反向通道）
- 启动时调 `DeadlineAlarmScheduler.apply(loadSnapshot().deadlineAlerts)` 重排

**改 [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)**
- 注册 `DeadlineAlarmReceiver`、`ReminderActionReceiver`（exported=false）
- `ReminderRescheduleReceiver` intent-filter 不变（已覆盖 BOOT/TIMEZONE/DATE_CHANGED）

**新 `DeadlineAlarmScheduler.kt`**
- 接收 `List<DeadlineAlert>`，批量排/取消 9:00 闹钟

### Flutter 端 — 3 改 1 新

**改 [lib/domain/entities/preparation_reminder.dart](lib/domain/entities/preparation_reminder.dart)**
- 新增 `PreparationReminderDigest`、`DeadlineAlert` 类 + `toJson`/`fromJson`
- `PreparationReminderSnapshot` 加 `digest`、`deadlineAlerts` 字段，`schemaVersion = 3`

**改 [lib/domain/services/preparation_reminder_builder.dart](lib/domain/services/preparation_reminder_builder.dart)**
- `build()` 计算 `digest`、`deadlineAlerts`，按 §2 规则

**改 [lib/core/platform/preparation_reminder_platform.dart](lib/core/platform/preparation_reminder_platform.dart)**
- `PreparationReminderPlatform` 接口加 `Future<void> completeTask(String planId)`
- `MethodChannelPreparationReminderPlatform` 实现：`invokeMethod('completeTask', planId)`
- 注意这是**反向通道**：原生调 Flutter，需要在 `MainActivity.configureFlutterEngine` 设置 `setMethodCallHandler`，Flutter 侧处理

**新 [lib/features/preparation/notifiers/complete_task_action_handler.dart]**（或挂在现有 provider 上）
- 暴露给 `MainActivity` 通过 MethodChannel 调用的完成方法
- 找到 plan → 标记该 plan 的「今日未完成最早任务」completed → 持久化 → 刷新 snapshot → `syncSnapshot` 回原生

### 反向通道

`completeTask` 是**原生 → Flutter** 的调用。复用现有 `com.example.scho_navi/preparation_reminders` 通道（同主题、减复杂度）。现有 `setRouteHandler` 已是类似模式，扩展即可：
- `MainActivity.configureFlutterEngine` 设置 `setMethodCallHandler` 时新增 `"completeTask"` 分支
- Flutter 侧通过同一个 `MethodChannel` 注册 handler，调用 `CompleteTaskActionHandler` 执行完成逻辑

## §4 错误处理

### 通知权限被拒
- 沿用现有 `ReminderNotificationStatus.denied` 状态
- 闹钟照排，`canNotify()` 检查通知权限 → 失败则静默不发（不崩溃）
- 用户在设置页重新授权后，下次闹钟响铃正常发出

### 完成任务反向通道失败
- `ReminderActionReceiver` 调 `invokeMethod("completeTask")` 用 `try/catch`
- 失败 → 通知不取消，让 `VIEW` 路径兜底（用户点通知正文仍能跳详情页手动完成）
- 防止「点了完成但任务没完成」的假成功

### 截止闹钟数据异常
- `deadlineAlerts` 为空 → `DeadlineAlarmScheduler.apply()` 取消所有截止闹钟后返回
- `alertIsoDay` 解析失败 → 跳过该条，不抛异常
- 同一 planId 重复闹钟 → 由 requestCode 唯一性（`planId.hashCode() * 10 + offsetIndex`）保证 `FLAG_UPDATE_CURRENT` 覆盖

### SNOOZE 边界
- 1h 后重发：用 `setAndAllowWhileIdle(RTC_WAKEUP, now+1h, pendingIntent)`
- 不再递归 SNOOZE（避免无限延迟链）；重发的通知若用户再点 SNOOZE → 走同一 requestCode，覆盖前一个 PendingAlarm
- 若重发时刻已跨日（>23:00 SNOOZE → 次日 0:00 后）→ 仍发，body 文案保持「下一项」语义

### Snapshot schema 降级
- 原生 `loadSnapshot` 已有 `schema !in 1..2 → 返回空` 的兜底
- 升级到 v3：`schema !in 1..3 → 返回空`，旧 v1/v2 仍解析（缺 digest/alerts 字段 → 默认值：digest.remainingToday=0、deadlineAlerts=空）
- 防止 Flutter 未升级但原生已升级（或反之）的过渡态崩溃

### 闹钟丢失（Doze / 重启）
- 现有 `ReminderRescheduleReceiver` 已处理 BOOT_COMPLETED / TIMEZONE_CHANGED / DATE_CHANGED
- 扩展：重启后同时重排 daily 闹钟 + 截止闹钟（`DeadlineAlarmScheduler.apply(loadSnapshot().deadlineAlerts)`）
- MY_PACKAGE_REPLACED 覆盖应用升级场景

### 完成今日任务的「今日」定义
- `completeTask(planId)` 完成的是该 plan 中 `dueDate == today && !completed` 的最早任务（按现有 `PreparationReminderBuilder` 的 incomplete 排序）
- 若该 plan 今日无未完成任务 → 标记该 plan 下一个最早的未完成任务（兜底，避免点了按钮无动作）
- 若该 plan 所有任务已完成 → 取消通知 + 不调通道（前端 snapshot 已无 nextTask，理论上不会触发）

### 多通知 ID 冲突
- 任务通知 ID = `4104`（保留）
- 摘要通知 ID = `4100`（新建，固定）
- 截止通知 ID = `4100000 + planId.hashCode().absoluteValue % 100000`（避免与任务/摘要冲突）
- 动作按钮不占通知 ID

## §5 测试策略

### Flutter 端（主战场，纯单元测试可覆盖核心逻辑）

**改 [test/domain/services/preparation_reminder_builder_test.dart](test/domain/services/preparation_reminder_builder_test.dart)**
- `digest` 计算用例：
  - 今日有未完成任务 → remainingToday 正确
  - 多 plan 跨截止日 → upcomingDeadlines / nearestDeadline 正确
  - 无 active plan → digest 全 0/空
- `deadlineAlerts` 计算用例：
  - targetDate 远 → 3 个 alert（d-7/d-3/d）
  - targetDate 已过 → 0 个 alert
  - targetDate 在 d-3 之后 → 只剩 d（去重保留最近）
  - 同 plan 多个 alert 按 alertIsoDay 升序
  - 多 plan 混合排序正确

**改 [test/core/platform/preparation_reminder_platform_test.dart](test/core/platform/preparation_reminder_platform_test.dart)**
- `completeTask` 调用 → 正确 invokeMethod 到 MethodChannel
- `completeTask` 通道错误 → 抛出/返回错误码（`null` + error 契约）

**改 [test/data/local/preparation_reminder_store_test.dart](test/data/local/preparation_reminder_store_test.dart)**（或 reminder 相关 store 测试）
- schema v3 snapshot 序列化/反序列化往返
- v2 snapshot 仍可解析（digest/alerts 默认值）

**新增反向通道 handler 测试**
- Mock MethodChannel handler：收到 `completeTask` 调用 → 正确找到 plan → 标记今日任务完成 → 刷新 snapshot

### 原生端（Kotlin）

现有 `test/` 下未见 Kotlin 测试基建（`android/app/src/test/` 不存在）。**不引入 Robolectric**（YAGNI + CI 复杂度）。改为：
- 截止闹钟时间计算逻辑（alertIsoDay 去重、sort）**全部放 Flutter 端**测，原生端只做 PendingIntent 排闹钟
- requestCode 唯一性靠代码审查 + 类型保证（`planId.hashCode() * 10 + offsetIndex`）
- 通知 channel 注册、动作按钮绑定靠**手动运行验证**（§6）

### 集成验证（手动，§6 详述）
- 真机/模拟器跑完整闭环

### TDD 节奏
- 严格 TDD：先写 Flutter 端 builder 测试（digest/alerts）→ 实现 → 通过
- 再写 platform 通道测试 → 实现
- 原生端改动配合手动验证

### completeTask 契约（已确认）
- 成功 `success(null)`、失败 `result.error(code, msg, null)`
- 与现有 `addDeadlineEvent`、`openNotificationSettings` 风格一致

## §6 验证清单

### 环境准备
- 模拟器 API 33+（TIRAMISU 需 POST_NOTIFICATIONS 运行时权限）
- 准备一个 active plan：`targetDate = 今天 + 10 天`，含今日到期未完成任务

### 场景 1 — 每日提醒 + 摘要（20:00）
1. 设置页开启提醒，时间设 20:00
2. `adb shell date` 改系统时间到 19:59:30
3. 等 30s+ → 应弹出：
   - 「备赛任务」通知（channel=preparation_tasks，标题「今晚推进「X」」）
   - 「每日摘要」通知（channel=preparation_tasks，标题「今日备赛摘要」，正文「今天还有 3 个任务…最近截止竞赛 X」）
   - 二者同 group，下拉后归组显示
4. 「备赛任务」通知有 3 按钮：完成今日任务 / 稍后提醒 / 查看计划

### 场景 2 — 截止提醒（d-7 / d-3 / d 当天 9:00）
1. plan targetDate = 今天 + 10 天 → snapshot 应含 3 个 alert（d-7/d-3/d）
2. 改系统时间到 d-7 当天 8:59 → 等 → 弹「竞赛截止」通知（channel=competition_deadlines，HIGH importance，带「查看计划」按钮）
3. 验证只有「查看计划」按钮（截止通知无完成/稍后）

### 场景 3 — 完成今日任务（动作闭环）
1. 在场景 1 的任务通知上点「完成今日任务」
2. 通知应消失
3. 进入详情页验证：今日最早未完成任务已标记 completed
4. snapshot 已刷新（再次进设置页或等下次闹钟验证 nextTask 已更新）

### 场景 4 — 稍后提醒
1. 点「稍后提醒」
2. 通知消失 → 1h 后重发同 planId 任务通知
3. 重发的通知仍有 3 按钮

### 场景 5 — 查看计划
1. 点「查看计划」→ 跳到 `/preparation-plans/{planId}` 详情页

### 场景 6 — 权限被拒
1. 系统设置关闭 SchoNavi 通知 → 闹钟照排但通知不弹 → 不崩溃
2. 重新开启 → 下次闹钟正常弹

### 场景 7 — 重启
1. 重启模拟器 → 开机后 daily 闹钟 + 截止闹钟都重排
2. `adb shell dumpsys alarm | grep scho_navi` 验证

### 场景 8 — 分组生效（关键，给评委看）
1. 构造多个 plan，让 20:00 同时触发任务通知 + 截止通知（手动调一个截止 alert 到 20:00）
2. 下拉通知栏 → 三类通知归到三个分组
3. 截图作为 AIGC 评分佐证
