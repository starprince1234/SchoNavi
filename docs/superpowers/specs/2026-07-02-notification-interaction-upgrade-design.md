# 通知交互升级设计

- 日期：2026-07-02
- 修订：v2（根据架构审查修订）
- 分支：iter4rc3
- 目标：把现有「单条每日提醒通知」升级为可在 App 未打开时工作的 Android 通知系统——多通道、真实通知分组、每日摘要、动作按钮闭环、独立截止提醒和重启恢复。

## 1. 范围与约束

### 1.1 本迭代范围

1. 备赛任务：每日目标时刻发送最紧急任务通知和备赛摘要。
2. 竞赛截止：在截止前 7/3/0 天的目标时刻 9:00 发送提醒。
3. 通知动作：
   - 完成此任务：不打开界面，完成通知所指向的确定任务。
   - 稍后提醒：约 1 小时后重新发送同一任务通知。
   - 查看计划：打开对应备赛计划详情页。
4. 系统恢复：应用升级、重启、日期变化和时区变化后恢复有效闹钟。

### 1.2 非目标

- 导师咨询本迭代只创建通知通道，不生成虚假通知来源。
- 不引入新的状态管理、路由、持久化或后台任务库。
- 不把通知动作实现为直接修改 Flutter `shared_preferences` 文件的原生 JSON 操作。
- 不承诺闹钟在目标分钟精确触发；本迭代使用 Android 的非精确闹钟策略。

### 1.3 时间语义

每日提醒和截止提醒使用 `AlarmManager.setAndAllowWhileIdle()`：

- 20:00、9:00 和“1 小时后”都是目标触发时间，系统保证不会早于该时间，但可能因系统批处理、节电或 Doze 延后。
- 产品文案和验收统一使用“目标时刻”“约 1 小时后”，不写“准时”或“精确”。
- 本迭代不申请 `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`。如后续产品要求精确提醒，应另立设计处理特殊权限、拒绝和撤销后的降级。

## 2. 架构决策

### 2.1 通知通道

| channel id | 名称 | importance | 用途 |
|---|---|---|---|
| `preparation_tasks` | 备赛任务 | DEFAULT | 每日任务和备赛摘要 |
| `competition_deadlines` | 竞赛截止 | HIGH | 截止前 7/3/0 天提醒 |
| `mentor_consultations` | 导师咨询 | DEFAULT | 结构占位，本迭代无通知来源 |

通道在 `MainActivity.onCreate` 时创建，各 Receiver 发送通知前再次幂等创建，保证冷启动接收广播时可用。首次升级到本版本后删除不再使用的旧通道 `preparation_reminders`，避免系统设置中同时出现新旧通道。

### 2.2 通知分组

通知通道与通知分组是两个独立概念。本迭代定义两个真实 group key：

| group key | 子通知 | summary |
|---|---|---|
| `scho_navi.preparation` | 每日最紧急任务 | 每日备赛摘要 |
| `scho_navi.deadlines` | 同一天触发的各竞赛截止提醒 | 当天有 2 条及以上截止提醒时创建 |

规则：

- 每个子通知和对应 summary 都必须调用 `setGroup(groupKey)`。
- summary 调用 `setGroupSummary(true)`。
- 备赛组使用 `GROUP_ALERT_SUMMARY`，避免任务子通知和摘要重复响铃。
- 截止组使用 `GROUP_ALERT_CHILDREN`；当天多条提醒仅子通知提示，summary 静默更新。
- Android 7.0+ 折叠态可能不展示自定义 summary 标题，验收以实际分组结构和展开后的子通知为准。
- 导师通道无通知，因此不声称存在导师通知分组。

### 2.3 Receiver 与协调器

| 组件 | 触发 | 职责 |
|---|---|---|
| `DailyReminderReceiver` | 每日目标时刻 | 重排下一次 daily；从持久化 snapshot 选择任务、计算当日摘要并发送备赛组 |
| `DeadlineAlarmReceiver` | 某个 alert day 的目标 9:00 | 批量发送当天全部截止子通知，必要时发送截止 summary |
| `SnoozedTaskReceiver` | 目标 `now + 1h` | 校验任务仍未完成后重新发送该任务通知 |
| `ReminderActionReceiver` | COMPLETE/SNOOZE 按钮 | 校验参数，执行后台动作；异步动作使用 `goAsync()` |
| `ReminderRescheduleReceiver` | BOOT / MY_PACKAGE_REPLACED / TIMEZONE_CHANGED / DATE_CHANGED | 重排 daily、future deadline day 和 future snooze 闹钟 |
| `NotificationActionCoordinator` | COMPLETE | 优先复用现有 UI FlutterEngine；不存在时启动一次性 headless FlutterEngine |

### 2.4 MethodChannel 方向

保留现有通道：

`com.example.scho_navi/preparation_reminders`

- 方向：Flutter → Android。
- 用途：`syncSnapshot`、`updateSchedule`、通知权限、Widget、日历和设置页。
- `PreparationReminderPlatform` 不新增 `completeTask()`；该接口仍只表达 Flutter 主动调用原生能力。

新增动作通道：

`com.example.scho_navi/notification_actions`

- 方向：Android → Flutter。
- UI engine 存在时，Android 调用 Dart 的 `completeNotificationTask`。
- UI engine 不存在时，原生启动 `notificationActionMain` headless entrypoint；该 entrypoint 完成动作后通过同一通道返回结果。
- MainActivity 的原生 `setMethodCallHandler` 不处理 `completeNotificationTask`；Dart 的 `setMethodCallHandler` 才处理该调用。

## 3. Snapshot schema v3

### 3.1 设计原则

- Flutter 负责导出经过领域规则筛选和排序的事实。
- 原生负责依赖“触发当天”的投影：今日剩余任务数、未来 30 天截止数、最近截止日和过期闹钟过滤。
- 不在 snapshot 中存一个只对生成当天有效的 `digest`，避免 App 多日未打开时摘要失真。
- snapshot JSON 继续由 `ReminderStorage` 持久化；Receiver 冷启动时必须可以完整恢复。

### 3.2 新增待完成任务事实

```dart
class PreparationReminderTask {
  final String taskId;
  final String title;
  final String dueIsoDay;
  final int sortOrder;
}
```

`PreparationReminderPlanSummary` 新增：

```dart
final List<PreparationReminderTask> pendingTasks;
```

规则：

- 只包含 active plan 中未完成任务。
- 排序沿用现有 builder 规则：`dueDate` → task kind rank → 原计划顺序。
- `sortOrder` 是上述排序后的稳定顺序，仅用于原生确定性比较。
- 保留现有 `nextTaskTitle`/`nextTaskDueDate` 字段，兼容 v1/v2 原生解析和现有 Widget；v3 在列表非空时取 `pendingTasks.first`，否则为 null。
- 通知动作必须携带 `planId + taskId`，禁止在点击时仅凭 planId 重新猜测任务。

### 3.3 截止提醒事实

```dart
class DeadlineAlert {
  final String planId;
  final String competitionName;
  final String alertIsoDay;
  final int daysBefore;        // 7 / 3 / 0
  final String deadlineIsoDay;
}
```

生成规则：

- 对每个 active plan 的 `targetDate` 生成 d-7、d-3、d 三条事实。
- Flutter 不按生成当天过滤过去日期，保证 snapshot 可在重启和跨日后由原生统一判断。
- 按 `alertIsoDay`、`deadlineIsoDay`、`planId`、`daysBefore` 排序。
- 原生调度时只保留 `alertIsoDay 09:00` 严格晚于当前时间的日期。

### 3.4 Snapshot 字段

```dart
class PreparationReminderSnapshot {
  static const schemaVersion = 3;

  final DateTime generatedAt;
  final int currentStreak;
  final bool preparedToday;
  final String? lastActivityDay;
  final List<PreparationReminderPlanSummary> plans;
  final List<DeadlineAlert> deadlineAlerts;
}
```

原生兼容规则：

- v1/v2：继续解析原字段，`pendingTasks`、`deadlineAlerts` 默认为空；可发送旧式查看通知，但不展示 COMPLETE 动作。
- v3：完整支持动作、跨日摘要和截止提醒。
- 未知高版本：返回空 snapshot，不崩溃、不误排闹钟。
- Dart 与 Kotlin 使用同一组 JSON fixture 验证兼容性。

## 4. 闹钟调度与持久化账本

### 4.1 Daily

- daily 只有一个闹钟，不按 planId 创建 requestCode。
- 每次触发后先调用 `ReminderScheduler.apply()` 排下一次目标时刻。
- 主提醒开关关闭时，取消 daily、deadline、snooze 闹钟和本应用当前通知。

### 4.2 Deadline 按日期批处理

`DeadlineAlarmScheduler` 不为每个 plan 单独排闹钟，而是按 `alertIsoDay` 分组：

1. 从 snapshot 取 `deadlineAlerts`。
2. 解析每个 `alertIsoDay` 在当前时区的 9:00。
3. 丢弃解析失败或目标时间 `<= now` 的日期。
4. 每个未来日期只排一个 `DeadlineAlarmReceiver`。
5. Receiver 触发后重新读取 snapshot，批量发送该日所有 alert，避免同一时刻多个 Receiver 竞争和重复 summary。

### 4.3 PendingIntent identity

不使用 `planId.hashCode()` 作为唯一性保证。PendingIntent 使用显式 component、固定 action 和唯一 data URI：

- daily：`schonavi://alarm/daily`
- deadline day：`schonavi://alarm/deadline/{isoDay}`
- snooze：`schonavi://alarm/snooze/{encodedPlanId}/{encodedTaskId}`
- action：`schonavi://notification/action/{action}/{encodedPlanId}/{encodedTaskId}`

extras 只承载展示数据，不参与 PendingIntent identity。所有 PendingIntent 使用 `FLAG_UPDATE_CURRENT | FLAG_IMMUTABLE`。

### 4.4 Alarm registry

`ReminderStorage` 新增持久化 `ReminderAlarmRegistry`，记录：

- 已排 deadline day 的 `isoDay + dataUri`；
- 已排 snooze 的 `planId + taskId + triggerAtEpochMs + dataUri`。

`reconcile()` 执行 old/new diff：

1. 重建 registry 中的旧 PendingIntent，取消不再需要或已经过期的项。
2. 创建/更新新的 future 项。
3. 原子写回新的 registry。

因此以下场景都有明确行为：

- `deadlineAlerts` 为空：取消 registry 中全部 deadline alarm。
- plan 被归档/删除：取消其不再出现的截止日期闹钟；若该日仍有其他 plan，保留该日批处理闹钟。
- 重启/升级/时区变化：根据持久化 snapshot 和 snooze registry 重建 future alarm。
- 已过期 snooze：直接丢弃，不在开机后补发陈旧任务提醒。

### 4.5 通知 identity

- 每日任务：`notify("task:$planId:$taskId", TASK_NOTIFICATION_ID, notification)`。
- 每日摘要：`notify("summary:preparation", PREPARATION_SUMMARY_ID, notification)`。
- 截止子通知：`notify("deadline:$planId:$daysBefore", DEADLINE_NOTIFICATION_ID, notification)`。
- 截止 summary：`notify("summary:deadlines:$alertIsoDay", DEADLINE_SUMMARY_ID, notification)`。

使用 `tag + id` 避免 `hashCode.absoluteValue`、整型溢出和不同 plan 冲突。

## 5. 通知生成

### 5.1 每日任务

`DailyReminderReceiver` 从所有 plan 的 `pendingTasks.firstOrNull` 中选最紧急项：

1. `dueIsoDay`
2. `sortOrder`
3. plan `targetDate`
4. `planId`

通知包含：

- 正文点击：查看计划。
- `完成此任务`：仅 v3 且 taskId 非空时展示。
- `稍后提醒`：仅 taskId 非空时展示。
- `查看计划`。

如果所有 active plan 均无待完成任务，只发送摘要，不发送空任务通知。

### 5.2 每日摘要

Receiver 以触发时的本地日期计算：

- `remainingToday`：所有 `pendingTasks.dueIsoDay == today` 的数量。
- `upcomingDeadlines`：active plan 中 `targetDate` 位于 `[today, today + 30d]` 的数量。
- `nearestDeadline`：`targetDate >= today` 的最早 plan。

摘要与任务通知使用 `scho_navi.preparation` group。由于数据按日期在原生投影，即使 App 连续多天未打开，摘要日期仍正确；任务完成状态以最近一次持久化 snapshot 为准。

### 5.3 截止提醒

`DeadlineAlarmReceiver` 按 intent 中的 `alertIsoDay` 读取 snapshot：

- 找出 `alertIsoDay == intent day` 的全部 alerts。
- 每个 alert 发送一条带“查看计划”按钮的子通知。
- 当 alerts 数量 >= 2 时发送 deadline summary。
- 没有匹配项时静默返回并清理该 registry entry。

## 6. 动作闭环

### 6.1 COMPLETE

流程：

```text
通知 COMPLETE
  → ReminderActionReceiver.goAsync()
  → NotificationActionCoordinator.complete(planId, taskId)
      ├─ UI FlutterEngine 可用：Android invokeMethod → Dart handler
      └─ UI FlutterEngine 不可用：启动 notificationActionMain headless engine
  → CompleteNotificationTaskUseCase
  → repository.findById(planId)
  → 精确查找 taskId，幂等完成并 repository.save()
  → 重新 build snapshot
  → 将 snapshotJson 返回原生
  → 原生 saveSnapshot + reconcile alarms + 刷新 Widget/通知
  → 成功后取消被点击的任务通知
```

Dart 用例规则：

- task 已完成：视为幂等成功，返回最新 snapshot。
- plan/task 不存在：返回 `not_found`，不修改其他任务。
- 禁止“今日无任务时自动完成未来任务”。
- repository CAS 冲突：重新读取一次；目标仍未完成时重试一次，第二次冲突返回 `conflict`。
- 完成时间使用 Dart 侧 `DateTime.now()`，保持现有领域语义。

### 6.2 Headless FlutterEngine 生命周期

- `notificationActionMain` 使用 `@pragma('vm:entry-point')`，只初始化完成任务所需的 SharedPreferences、repository、builder 和 action channel，不启动 UI。
- 原生确保插件在 headless engine 注册后再执行 entrypoint。
- `NotificationActionCoordinator` 在进程内 single-flight，避免 UI engine 与 headless engine 同时处理同一动作。
- `BroadcastReceiver.PendingResult` 在成功、失败或超时路径都必须 `finish()`。
- 超时上限 8 秒；超时或 engine 初始化失败时销毁 headless engine，并保留通知供用户改走“查看计划”。
- UI Activity 在 `configureFlutterEngine`/`cleanUpFlutterEngine` 向 coordinator 注册/注销可用 action channel，Receiver 不直接持有 MainActivity 实例。

### 6.3 COMPLETE 返回契约

成功返回：

```json
{
  "status": "completed",
  "snapshotJson": "{...schema v3...}"
}
```

幂等成功返回 `status = "already_completed"`，同样包含最新 snapshot。失败使用 Flutter error：

- `invalid_arguments`
- `not_found`
- `conflict`
- `persistence_failed`
- `timeout`

只有收到成功结果后才取消任务通知，防止假成功。

### 6.4 SNOOZE

- 点击后立即取消当前任务通知，排一个目标 `now + 1h` 的非精确闹钟。
- 只重发任务通知，不重发每日摘要。
- snooze 记录写入 alarm registry；同一 `planId + taskId` 再次 snooze 时覆盖旧记录。
- 允许再次点击 SNOOZE，不人为限制延迟次数。
- 重发前从最新 snapshot 校验该 taskId 仍存在于 pendingTasks；已完成、计划归档或删除则静默取消。
- 跨日后仍可重发，文案使用“待办任务”，不再写“今日任务”。

### 6.5 VIEW

- 使用 `PendingIntent.getActivity` 打开 MainActivity。
- route 固定为 `/preparation-plans/{encodedPlanId}`。
- 复用现有 `EXTRA_ROUTE`、`takeInitialRoute` 和 `openRoute` 流程。

## 7. 文件改动清单

### 7.1 Android/Kotlin

**改 `ReminderScheduler.kt`**

- `ReminderReceiver` 拆为 `DailyReminderReceiver`。
- daily 使用固定 data URI；触发后重排下一次。
- 提取日期投影和最紧急任务选择为可测试纯函数。

**改 `ReminderStorage.kt`**

- 解析 schema v3 的 `pendingTasks`、`deadlineAlerts`。
- 持久化 snapshot 和 `ReminderAlarmRegistry`。
- v1/v2/v3 兼容解析。

**新 `DeadlineAlarmScheduler.kt`**

- 按 alert day 批处理调度。
- registry old/new diff、过期过滤和恢复。

**新 `ReminderNotificationFactory.kt`**

- 创建三个 channel、两个 group 的 child/summary 通知。
- 统一通知 tag/id、PendingIntent data URI 和动作参数。

**新 `ReminderActionReceiver.kt`**

- COMPLETE/SNOOZE 分发。
- COMPLETE 使用 `goAsync()`；SNOOZE 更新 registry。
- 包含 `SnoozedTaskReceiver`。

**新 `NotificationActionCoordinator.kt`**

- 管理 UI action channel、headless FlutterEngine、single-flight、超时和结果回调。

**改 `MainActivity.kt`**

- 创建并向 coordinator 注册 `notification_actions` 通道。
- 启动时创建 channels、保存 legacy channel migration 标记并 reconcile alarms。
- 不在 `handleReminderCall` 中添加方向错误的 `completeTask` 分支。

**改 `AndroidManifest.xml`**

- 将 `.ReminderReceiver` 替换为 `.DailyReminderReceiver`。
- 注册 `DeadlineAlarmReceiver`、`ReminderActionReceiver`、`SnoozedTaskReceiver`，均 `exported=false`。
- 保留 BOOT_COMPLETED、MY_PACKAGE_REPLACED、TIMEZONE_CHANGED、DATE_CHANGED。
- 不新增 exact alarm 权限。

### 7.2 Flutter/Dart

**改 `lib/domain/entities/preparation_reminder.dart`**

- 新增 `PreparationReminderTask`、`DeadlineAlert`。
- plan summary 新增 `pendingTasks`；snapshot 新增 `deadlineAlerts`。
- schemaVersion 升到 3。

**改 `lib/domain/services/preparation_reminder_builder.dart`**

- 构建排序后的 pendingTasks。
- 为每个 active plan 构建完整 d-7/d-3/d facts，不按 today 过滤。

**改 `lib/core/platform/preparation_reminder_platform.dart`**

- 保持 Flutter → Android 接口不变。
- 不添加 `completeTask()`。

**新 `lib/features/preparation/services/complete_notification_task_use_case.dart`**

- 精确按 planId/taskId 幂等完成任务。
- 保存计划、处理一次 CAS 重试、构建并返回 snapshot。

**改 `lib/features/preparation/providers/preparation_reminder_providers.dart`**

- UI engine 为 `notification_actions` 注册 Dart handler。
- handler 委托给同一个 complete use case。

**改 `lib/main.dart`**

- 增加 `@pragma('vm:entry-point') notificationActionMain`。
- headless 路径初始化最小依赖并回传动作结果，不调用 `runApp()`。

## 8. 错误与恢复

### 8.1 通知权限被拒

- 闹钟和 registry 仍维护，发送前 `canNotify()`；无权限时静默返回。
- 用户重新授权后，后续闹钟正常发送。
- 通知权限不影响 COMPLETE 已经开始执行的动作结果。

### 8.2 Snapshot 或日期异常

- JSON、日期或必填 ID 无效时跳过对应项，不使整个 Receiver 崩溃。
- 未知 schema 返回空数据并取消无法证明仍有效的 deadline alarms。
- 任何 scheduler 都不得把 `triggerAt <= now` 的 deadline 重新排入 AlarmManager。

### 8.3 后台动作失败

- 通知保留；用户仍可点正文或“查看计划”手动处理。
- headless engine、PendingResult 和临时 channel 在所有路径释放。
- 日志只记录错误码和 plan/task 的非敏感标识，不记录完整 snapshot。

## 9. 测试策略

### 9.1 Flutter 单元测试

`preparation_reminder_builder_test.dart`：

- pendingTasks 包含 taskId、仅含未完成项，并按既有规则排序。
- nextTask 字段与 pendingTasks.first 一致。
- 每个 active plan 固定生成 d-7/d-3/d 三条 alert，包括生成时已经过去的点。
- archived plan 不生成任务事实或 deadline alert。
- 多 plan alerts 排序稳定。

`complete_notification_task_use_case_test.dart`：

- 精确完成指定 taskId，不影响同 plan 其他任务。
- task 已完成时幂等成功。
- plan/task 不存在时不完成其他任务。
- CAS 冲突重读并只重试一次。
- 成功保存后返回 schema v3 snapshot。

`preparation_reminder_platform_test.dart`：

- 现有 Flutter → Android 调用保持不变。
- UI action handler 收到 Android `completeNotificationTask` 后返回规定 payload/error。

### 9.2 Kotlin JVM 测试

不引入 Robolectric；将纯逻辑提取后测试：

- v1/v2/v3 JSON fixture 解析和未知 schema 降级。
- 当日 digest 在跨日时按触发日重新计算。
- deadline alerts 按日期分组、过去时间过滤。
- alarm registry old/new diff 能取消被删除 plan 的孤儿闹钟。
- data URI identity 对特殊字符 planId/taskId 正确编码且互不冲突。
- 通知 tag 不依赖 hashCode。

### 9.3 Android 集成验证

必须覆盖：

1. App 前台点击 COMPLETE。
2. 任务通知出现后退到后台，执行 `adb shell am kill com.example.scho_navi`（不要使用会进入 stopped state 的 `force-stop`），再点击 COMPLETE，验证 headless 路径。
3. COMPLETE 失败时通知不消失。
4. 删除/归档计划后 `dumpsys alarm` 中无孤儿 deadline alarm。
5. 重启、时区变化、日期变化后只恢复 future alarm。
6. SNOOZE 后任务已在 App 内完成，目标时间不再重发。

## 10. 验收清单

### 场景 1：每日任务与摘要

1. 准备至少一个 active plan，含待完成任务。
2. 将提醒目标时间设为接近当前时间，等待系统投递。
3. 验证任务与摘要属于 `scho_navi.preparation`，只产生一次提示音。
4. 展开后任务通知有“完成此任务 / 稍后提醒 / 查看计划”。

### 场景 2：跨日摘要

1. 同步 snapshot 后不再打开 App。
2. 跨到次日并触发 daily。
3. 摘要的“今日剩余”必须按触发当天统计，不得沿用 snapshot 生成日。

### 场景 3：截止批处理与分组

1. 构造两个 plan，使同一天存在 deadline alert。
2. 在允许调整系统时间的测试模拟器中把时间设到该 alert day 的 8:59，等待目标 9:00 闹钟投递；不修改生产调度规则。
3. 验证两条截止子通知和一个 `scho_navi.deadlines` summary。

### 场景 4：后台完成动作

1. 发送包含确定 planId/taskId 的任务通知。
2. 结束 Activity/Flutter UI engine 后点击“完成此任务”。
3. 通知成功消失；重新打开 App 后指定 taskId 已完成，其他任务未变化。
4. 模拟 persistence error，验证通知保留。

### 场景 5：稍后提醒

1. 点击“稍后提醒”，当前任务通知消失，registry 出现该 task 的 snooze 记录。
2. 目标约 1 小时后任务仍未完成时重发任务通知，不重发摘要。
3. 提前完成任务后不重发。

### 场景 6：查看计划

点击正文或“查看计划”，冷启动和热启动都进入 `/preparation-plans/{planId}`。

### 场景 7：权限与恢复

1. 关闭通知权限，闹钟触发不崩溃；恢复权限后后续提醒可见。
2. 重启后 daily、future deadline day、future snooze 被恢复，过去项被清理。
3. `adb shell dumpsys alarm` 验证不存在已删除 plan 导致的孤儿闹钟。

### 场景 8：给评委展示的系统能力

展示内容应准确描述为：

- 系统设置中存在三个独立 notification channel。
- 通知栏中存在一个备赛任务组；构造同日多截止时存在一个截止提醒组。
- COMPLETE 在 App UI 未运行时可通过 headless Flutter 完成确定任务。
- SNOOZE、VIEW、重启恢复和权限拒绝均有真实闭环。

不得把“3 个 channel”描述为“3 个 notification group”，也不为导师通道制造占位通知。
