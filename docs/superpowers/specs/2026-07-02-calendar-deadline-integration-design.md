# 备赛截止日一键加入系统日历 — 设计规格

- 日期：2026-07-02
- 分支：iter4rc3
- 范围：备赛计划的「报名截止」「提交截止」一键写入 Android 系统日历

## 1. 背景与目标

备赛计划里的截止节点（报名截止、提交截止）对学术/竞赛导航实用性强。用户希望「一键加入系统日历」，避免手动在日历 App 里逐条录入。

当前数据模型只有 `targetDate`（提交截止/比赛日）一个真实截止日期，`eventEndDate`（窗口型比赛结束日）与 `defenseDate`（答辩日）为可选辅助字段；**没有「报名截止」字段**。本次新增 `registrationDeadline` 可空字段，由用户在表单手动填写（不编造日期，符合 LLM/data grounding 原则）。

目标：在备赛详情页为每个截止日提供独立「加入日历」入口，Android 端原生写入 `CalendarContract`，失败时 fallback 到系统日历 App 的 INSERT intent。

## 2. 需求决策（澄清结论）

| 维度 | 决策 |
|---|---|
| 覆盖节点 | 仅竞赛截止日：报名截止 + 提交截止（不含 phase.task） |
| 写入方式 | 原生 MethodChannel 写日历（复用现有架构） |
| 失败兜底 | 原生写入失败 → fallback INSERT intent 跳日历 App |
| 入口位置 | 截止日卡片各自独立入口（非顶部汇总按钮） |
| 平台范围 | 仅 Android（iOS/Web 入口可见但提示不支持，与现有 `isSupported` 一致） |
| 报名截止字段 | 新增 `registrationDeadline` 可空字段 |
| 字段来源 | 表单手动填写（生成器默认 null，不编造） |

## 3. 数据模型与表单

### 3.1 实体变更 — [lib/domain/entities/preparation_plan.dart](lib/domain/entities/preparation_plan.dart)

`PreparationPlan` 新增字段：

```dart
final DateTime? registrationDeadline;
```

- 构造函数增加 `this.registrationDeadline`（可空，无默认值，位于 `defenseDate` 之后）
- `copyWith` 增加 `DateTime? registrationDeadline` 参数
- `toJson`：`if (registrationDeadline != null) 'registration_deadline': CalendarDate.toIsoDay(registrationDeadline!)`（与 `eventEndDate`/`defenseDate` 同模式，存 ISO 日）
- `fromJson`：`registrationDeadline: json['registration_deadline'] == null ? null : CalendarDate.parseIsoDay(json['registration_deadline'] as String)`（同 `defenseDate` 模式）
- 若存在手写 `==`/`hashCode`，补上该字段

向后兼容：旧 JSON 无该字段时 `fromJson` 容错为 null，老计划读出后 `registrationDeadline == null`，不迁移、不编造。

### 3.2 表单变更 — [lib/features/preparation/pages/preparation_plan_form_page.dart](lib/features/preparation/pages/preparation_plan_form_page.dart)

- 新增「报名截止日期」可选 DatePicker 字段（可空）
- 校验：若填写，必须 `< targetDate`（提交截止必在报名截止之后），违反时表单显示校验错误、阻止提交
- 提交时写入 `PreparationPlan.registrationDeadline`

### 3.3 生成器

`PreparationPlanGenerator` **不改动**，生成的 plan 默认 `registrationDeadline == null`，由用户后续在表单补充。

## 4. 平台抽象层与原生实现

### 4.1 Dart 平台抽象 — [lib/core/platform/preparation_reminder_platform.dart](lib/core/platform/preparation_reminder_platform.dart)

`PreparationReminderPlatform` 接口新增：

```dart
Future<CalendarAddResult> addDeadlineEvent(CalendarDeadlineEvent event);
```

新增值类 `CalendarDeadlineEvent`（不可变，纯 Dart，便于测试序列化）：

```dart
class CalendarDeadlineEvent {
  const CalendarDeadlineEvent({
    required this.title,
    required this.dateMs,
    this.allDay = true,
    this.location,
    this.notes,
  });
  final String title;
  final int dateMs;      // epoch 毫秒，00:00 local
  final bool allDay;
  final String? location;
  final String? notes;
  Map<String, dynamic> toJson() => { ... };
}
```

新增枚举 `CalendarAddResult { success, fallbackIntentLaunched, unsupported, failed }`：

| 值 | 含义 |
|---|---|
| `success` | 原生写入 CalendarContract 成功 |
| `fallbackIntentLaunched` | 原生失败但 INSERT intent 已跳日历 App（用户需手动保存） |
| `unsupported` | 当前平台/设备不支持（iOS/Web/无日历且无日历 App） |
| `failed` | 原生与 intent 均失败 |

`MethodChannelPreparationReminderPlatform` 实现：
- `isSupported` 沿用现有（`!kIsWeb && defaultTargetPlatform == TargetPlatform.android`）
- `_channel.invokeMethod<String>('addDeadlineEvent', event.toJson())` → 返回 `'success' | 'fallback' | 'unsupported' | 'failed'` → 映射枚举
- 不支持时直接返回 `unsupported`，不调用原生

### 4.2 Android 原生 — [android/app/src/main/kotlin/com/example/scho_navi/MainActivity.kt](android/app/src/main/kotlin/com/example/scho_navi/MainActivity.kt)

`handleReminderCall` 新增分支 `addDeadlineEvent`：

1. 解析 JSON 参数（title/dateMs/allDay/notes）
2. 检查 `WRITE_CALENDAR` 运行时权限（API ≥ 23）：
   - 未授权 → 通过新增 `pendingCalendarPermissionResult`（独立于现有 `pendingPermissionResult`，避免冲突）请求权限，回调后继续写入流程
3. 有权限 → 查询 `CalendarContract.Calendars` 取第一个可写日历账户 → `ContentResolver.insert` 写入 `CalendarContract.Events`：
   - `DTSTART = DTEND = dateMs`，`ALL_DAY = 1`，`EVENT_TIMEZONE = "UTC"`，`TITLE = title`，`DESCRIPTION = notes`
   - 写入成功 → 返回 `"success"`
   - 写入失败（无账户/异常）→ 进入 fallback
4. fallback：构造 `Intent(android.intent.action.INSERT)` 预填 title/begin/end/allDay（用 `CalendarContract.Events.CONTENT_URI` 作为 data，Extras 设 `Events.TITLE`/`Events.DTSTART`/`Events.DTEND`/`Events.ALL_DAY`），`startActivity`（`try/catch` 处理 `ActivityNotFoundException`）
   - intent 成功启动 → 返回 `"fallback"`
   - intent 失败 → 返回 `"failed"`

`onRequestPermissionsResult` 增加对 `CALENDAR_PERMISSION_REQUEST` code 的分支，回调 `pendingCalendarPermissionResult`。

### 4.3 AndroidManifest 权限

[android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) 新增：

```xml
<uses-permission android:name="android.permission.READ_CALENDAR"/>
<uses-permission android:name="android.permission.WRITE_CALENDAR"/>
```

（查询日历账户需要 READ，写入需要 WRITE。）

## 5. UI 入口与交互

### 5.1 截止日卡片 — `lib/features/preparation/widgets/preparation_deadline_card.dart`（新建）

`PreparationDeadlineCard`（StatelessWidget）：
- 输入：`label`（"报名截止"/"提交截止"）、`date`（DateTime?）、`onAddToCalendar`（VoidCallback?）、`adding`（bool，按钮 loading 态）
- 渲染：`BentoTile` 内一行 = 图标 + 标签 + 日期文案 + 「加入日历」`IconButton`（`Icons.event_available_outlined`）
- `date == null`：显示「未设置」+ 不渲染按钮
- 点击按钮调用 `onAddToCalendar`

### 5.2 详情页集成 — [lib/features/preparation/pages/preparation_plan_detail_page.dart](lib/features/preparation/pages/preparation_plan_detail_page.dart)

- 在 `PreparationCountdown` 与 `PreparationPhaseTimeline` 之间插入 `Column`：
  - `PreparationDeadlineCard(label: '报名截止', date: plan.registrationDeadline, ...)`
  - `PreparationDeadlineCard(label: '提交截止', date: plan.targetDate, ...)`
- 新增 `_addToCalendar({required String label, required DateTime? date})`：
  - `date == null` 直接 return
  - 构造 `CalendarDeadlineEvent(title: '${plan.competition.name}·$label', dateMs: date.millisecondsSinceEpoch, allDay: true, notes: '由 SchoNavi 备赛计划添加')`
  - 调 `ref.read(preparationReminderPlatformProvider).addDeadlineEvent(event)`
  - `_addingLabel` state 标记当前正在处理的卡片，按钮 disable 防重；其他卡片仍可独立点击
  - 完成后调 `_showCalendarResultSnackBar(result)`
- `_showCalendarResultSnackBar` 按 `CalendarAddResult` 给 4 种提示：
  - `success` → "已加入系统日历"
  - `fallbackIntentLaunched` → "已打开日历 App，请确认保存"
  - `unsupported` → "当前设备不支持，请手动添加"
  - `failed` → "加入日历失败，请稍后重试"

## 6. 错误处理边界

| 场景 | 行为 |
|---|---|
| `date == null`（老计划无报名截止） | 卡片显示「未设置」，不渲染「加入日历」按钮 |
| `WRITE_CALENDAR` 权限被拒 | 原生走 fallback intent；intent 也失败 → `failed` |
| 设备无日历账户 | `CalendarContract.Calendars` 查询为空 → fallback intent |
| 设备无日历 App | intent `startActivity` 抛 `ActivityNotFoundException` → `failed` |
| iOS / Web | `isSupported=false` → 直接 `unsupported`，不调用原生 |
| MethodChannel 异常 | `try/catch` → `failed`（UI 提示重试） |

## 7. 测试清单

### 7.1 单元测试
- [test/domain/entities/preparation_plan_test.dart](test/domain/entities/preparation_plan_test.dart)：`registrationDeadline` 的 `toJson/fromJson/copyWith` 往返；null 不写入 JSON；旧 JSON（无该字段）`fromJson` 容错为 null（向后兼容）
- `test/core/platform/calendar_deadline_event_test.dart`（新建）：`CalendarDeadlineEvent.toJson` 序列化正确性

### 7.2 Widget 测试
- `test/features/preparation/widgets/preparation_deadline_card_test.dart`（新建）：date=null 无按钮；date 有值点击触发 `onAddToCalendar`；`adding=true` 时按钮 disable
- [test/features/preparation/pages/preparation_plan_detail_page_test.dart](test/features/preparation/pages/preparation_plan_detail_page_test.dart)（如已存在则补充）：fake platform 返回 `success` → 出现「已加入系统日历」SnackBar；返回 `unsupported` → 出现「当前设备不支持」提示

### 7.3 表单测试
- [test/features/preparation/pages/preparation_plan_form_page_test.dart](test/features/preparation/pages/preparation_plan_form_page_test.dart)（如已存在则补充）：报名截止可空；填写时约束 `< targetDate`，违反时显示校验错误并阻止提交

### 7.4 Fake platform 扩展
- `_FakePreparationReminderPlatform` 增加 `addDeadlineEvent` 实现，返回值可配置，供 widget 测试断言

### 7.5 原生层
- 不做 Kotlin 单元测试（与现有 `pinWidget`/通知一致），靠手动验证

## 8. 验证期望

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test test/domain/entities/preparation_plan_test.dart
flutter test test/core/platform/calendar_deadline_event_test.dart
flutter test test/features/preparation/widgets/preparation_deadline_card_test.dart
flutter test test/features/preparation/pages/preparation_plan_detail_page_test.dart
flutter test test/features/preparation/pages/preparation_plan_form_page_test.dart
```

UI 手动验证（Android 设备/模拟器）：
- 备赛详情页点「加入日历」→ 事件出现在系统日历 App
- 拒绝日历权限后点 → 跳日历 App（fallback intent）
- iOS/Web 上按钮提示不支持

如本地无法验证 iOS，明确说明。

## 9. 不在本次范围

- 不动 AI/HTTP assistant、生成器、模板 schema（`registrationDeadline` 默认 null）
- 不迁移老计划数据（保持 null，诚实不编造）
- 不批量写入 phase.task 的 `dueDate`
- 不引入第三方日历包
- 不支持 iOS/Web 原生写入
