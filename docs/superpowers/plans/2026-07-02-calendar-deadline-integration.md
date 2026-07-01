# 备赛截止日一键加入系统日历 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在备赛详情页为「报名截止」「目标日期」提供独立「加入日历」入口，Android 端原生写入 `CalendarContract`，失败 fallback 到 INSERT intent。

**Architecture:** `PreparationPlan` 新增可空 `registrationDeadline` 字段（sentinel copyWith 支持清空）；`PreparationReminderPlatform` 新增 `addDeadlineEvent(CalendarDeadlineEvent)` → `CalendarAddResult`；Android `MainActivity.kt` 走 READ/WRITE_CALENDAR 权限 → `CalendarContract` 写入 → fallback intent。UI 在备赛详情页插两张 `PreparationDeadlineCard`，标签按 `timelineType` 切换「提交截止」/「比赛开始」。

**Tech Stack:** Flutter/Dart, flutter_riverpod, go_router, Android Kotlin MethodChannel, CalendarContract。

## Global Constraints

- 不引入新第三方库（CLAUDE.md 禁止擅自引入新状态管理/HTTP/持久化/路由/日历包）。
- 不动 AI/HTTP assistant、`PreparationPlanGenerator`、模板 schema：`registrationDeadline` 默认 null，不编造日期（LLM/data grounding 原则）。
- 仅 Android 支持原生写入；iOS/Web `isSupported=false` 直接返回 `unsupported`（与现有 `pinWidget`/通知模式一致）。
- 保留中文产品文案风格（受影响屏幕均为中文）。
- `copyWith` 用 sentinel 区分「不改动」与「清空为 null」，否则无法清空报名截止。
- 跨原生边界传 `isoDay`（`YYYY-MM-DD` 字符串），不传本地 `millisecondsSinceEpoch`，避免全天事件在非 UTC 时区漂移。
- 测试用 `ProviderScope` overrides，不引入全局可变状态。
- 提交时 stage 具体文件，commit message 遵循现有 `feat(domain):`/`feat(preparation):` 风格。

---

## File Structure

| 文件 | 责任 | 操作 |
|---|---|---|
| `lib/domain/entities/preparation_plan.dart` | `PreparationPlan` 实体，新增 `registrationDeadline` + sentinel copyWith | Modify |
| `lib/core/platform/preparation_reminder_platform.dart` | 平台抽象，新增 `CalendarDeadlineEvent`/`CalendarAddResult`/`addDeadlineEvent` | Modify |
| `android/app/src/main/AndroidManifest.xml` | 新增 READ/WRITE_CALENDAR 权限 | Modify |
| `android/app/src/main/kotlin/com/example/scho_navi/MainActivity.kt` | 原生 `addDeadlineEvent` 分支 + 权限回调 | Modify |
| `lib/features/preparation/widgets/preparation_deadline_card.dart` | 截止日卡片组件 | Create |
| `lib/features/preparation/pages/preparation_plan_detail_page.dart` | 详情页集成卡片 + `_addToCalendar` + `_editRegistrationDeadline` | Modify |
| `lib/features/preparation/pages/preparation_plan_form_page.dart` | 表单新增报名截止字段 | Modify |
| `test/domain/entities/preparation_plan_test.dart` | 实体序列化/copyWith 测试 | Modify |
| `test/core/platform/calendar_deadline_event_test.dart` | `CalendarDeadlineEvent.toJson` 测试 | Create |
| `test/features/preparation/widgets/preparation_deadline_card_test.dart` | 卡片 widget 测试 | Create |
| `test/features/preparation/pages/preparation_plan_detail_page_test.dart` | 详情页日历交互测试 | Create/Modify |
| `test/features/preparation/pages/preparation_plan_form_page_test.dart` | 表单报名截止校验测试 | Create/Modify |

---

## Task 1: 实体新增 registrationDeadline（sentinel copyWith）

**Files:**
- Modify: `lib/domain/entities/preparation_plan.dart`
- Test: `test/domain/entities/preparation_plan_test.dart`

**Interfaces:**
- Consumes: `CalendarDate.toIsoDay` / `CalendarDate.parseIsoDay`（已存在，见 `defenseDate` 模式）
- Produces: `PreparationPlan.registrationDeadline`（`DateTime?`）；`PreparationPlan.copyWith(registrationDeadline: ...)` 支持 sentinel（传 `null` 清空、不传保留旧值）

- [ ] **Step 1: 写失败测试 — 序列化往返**

在 `test/domain/entities/preparation_plan_test.dart` 末尾 `main()` 内追加：

```dart
test('registrationDeadline toJson/fromJson 往返', () {
  final plan = _basePlan().copyWith(
    registrationDeadline: DateTime(2026, 8, 15),
  );
  final json = plan.toJson();
  expect(json['registration_deadline'], '2026-08-15');
  final restored = PreparationPlan.fromJson(json);
  expect(restored.registrationDeadline, DateTime(2026, 8, 15));
});

test('registrationDeadline 为 null 时不写入 JSON', () {
  final plan = _basePlan().copyWith(); // 不设置
  final json = plan.toJson();
  expect(json.containsKey('registration_deadline'), isFalse);
  expect(PreparationPlan.fromJson(json).registrationDeadline, isNull);
});

test('旧 JSON 无 registration_deadline 字段时容错为 null', () {
  final json = _basePlan().toJson();
  json.remove('registration_deadline');
  expect(PreparationPlan.fromJson(json).registrationDeadline, isNull);
});

test('copyWith registrationDeadline=null 清空，不传保留旧值', () {
  final plan = _basePlan().copyWith(registrationDeadline: DateTime(2026, 8, 15));
  expect(plan.registrationDeadline, DateTime(2026, 8, 15));
  // 不传 → 保留
  final kept = plan.copyWith(targetDate: DateTime(2026, 9, 2));
  expect(kept.registrationDeadline, DateTime(2026, 8, 15));
  // 显式传 null → 清空
  final cleared = plan.copyWith(registrationDeadline: null);
  expect(cleared.registrationDeadline, isNull);
});
```

如果 `_basePlan()` helper 不存在，在测试文件顶部加：

```dart
PreparationPlan _basePlan() => PreparationPlan(
  id: 'p1',
  competition: CompetitionSnapshot(
    id: 'c1',
    name: 'ACM-ICPC',
    category: '计算机类',
    rulesSummary: CompetitionRulesSummary(
      signupTime: '',
      contestTime: '',
      teamSize: '',
      format: '',
      organizer: '',
      officialUrl: null,
    ),
  ),
  targetDate: DateTime(2026, 9, 1),
  weeklyCommitment: WeeklyCommitment.hours6to10,
  experienceLevel: ExperienceLevel.beginner,
  status: PreparationPlanStatus.active,
  phases: const [],
  createdAt: DateTime(2026, 6, 28),
  updatedAt: DateTime(2026, 6, 28),
);
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/domain/entities/preparation_plan_test.dart --plain-name "registrationDeadline"`
Expected: 编译失败 — `registrationDeadline` 字段/参数不存在。

- [ ] **Step 3: 实现实体变更**

在 `lib/domain/entities/preparation_plan.dart`：

1) 在 `defenseDate` 字段后加：

```dart
  final DateTime? registrationDeadline;
```

2) 构造函数在 `this.defenseDate,` 之后加 `this.registrationDeadline,`

3) 在文件顶部 import 区下方、`PreparationPlan` 类上方加 sentinel：

```dart
final Object _registrationDeadlineUnset = Object();
```

4) `copyWith` 签名：在 `DateTime? defenseDate,` 后加：

```dart
    Object? registrationDeadline = _registrationDeadlineUnset,
```

并在 `copyWith` 体内 `defenseDate: defenseDate ?? this.defenseDate,` 之后加：

```dart
    registrationDeadline: identical(registrationDeadline, _registrationDeadlineUnset)
        ? this.registrationDeadline
        : registrationDeadline as DateTime?,
```

5) `toJson` 在 `if (defenseDate != null) 'defense_date': CalendarDate.toIsoDay(defenseDate!),` 之后加：

```dart
    if (registrationDeadline != null)
      'registration_deadline': CalendarDate.toIsoDay(registrationDeadline!),
```

6) `fromJson` 在 `defenseDate:` 赋值之后加：

```dart
        registrationDeadline: json['registration_deadline'] == null
            ? null
            : CalendarDate.parseIsoDay(json['registration_deadline'] as String),
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/domain/entities/preparation_plan_test.dart`
Expected: PASS（全部测试，含新增 4 个）

- [ ] **Step 5: 提交**

```bash
git add lib/domain/entities/preparation_plan.dart test/domain/entities/preparation_plan_test.dart
git commit -m "feat(domain): PreparationPlan 新增 registrationDeadline 字段（sentinel copyWith）"
```

---

## Task 2: 平台抽象新增 CalendarDeadlineEvent / CalendarAddResult / addDeadlineEvent

**Files:**
- Modify: `lib/core/platform/preparation_reminder_platform.dart`
- Test: `test/core/platform/calendar_deadline_event_test.dart`

**Interfaces:**
- Consumes: 无
- Produces:
  - `class CalendarDeadlineEvent { const CalendarDeadlineEvent({required String title, required String isoDay, String? location, String? notes}); Map<String, dynamic> toJson(); }`
  - `enum CalendarAddResult { success, fallbackIntentLaunched, unsupported, failed }`
  - `PreparationReminderPlatform.addDeadlineEvent(CalendarDeadlineEvent event) → Future<CalendarAddResult>`
  - `MethodChannelPreparationReminderPlatform.addDeadlineEvent` 实现（invokeMethod `'addDeadlineEvent'`，返回字符串映射枚举，异常 catch 返回 `failed`）

- [ ] **Step 1: 写失败测试 — CalendarDeadlineEvent.toJson**

新建 `test/core/platform/calendar_deadline_event_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/platform/preparation_reminder_platform.dart';

void main() {
  test('CalendarDeadlineEvent.toJson 包含必填字段', () {
    final event = CalendarDeadlineEvent(
      title: 'ACM-ICPC·报名截止',
      isoDay: '2026-08-15',
    );
    expect(event.toJson(), {
      'title': 'ACM-ICPC·报名截止',
      'isoDay': '2026-08-15',
    });
  });

  test('CalendarDeadlineEvent.toJson 包含可选字段', () {
    final event = CalendarDeadlineEvent(
      title: 'X·提交截止',
      isoDay: '2026-09-01',
      location: '线上',
      notes: '由 SchoNavi 备赛计划添加',
    );
    expect(event.toJson(), {
      'title': 'X·提交截止',
      'isoDay': '2026-09-01',
      'location': '线上',
      'notes': '由 SchoNavi 备赛计划添加',
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/core/platform/calendar_deadline_event_test.dart`
Expected: 编译失败 — `CalendarDeadlineEvent` 未定义。

- [ ] **Step 3: 实现值类与枚举**

在 `lib/core/platform/preparation_reminder_platform.dart` 顶部 import 之后、`typedef ReminderRouteHandler` 之前加：

```dart
/// 写入系统日历的截止日事件（spec §4.1）。
///
/// 跨 MethodChannel 边界只传 ISO 日字符串，避免本地零点 ms 在非 UTC
/// 时区造成全天事件漂移；原生侧按 UTC 日历日转边界。
class CalendarDeadlineEvent {
  const CalendarDeadlineEvent({
    required this.title,
    required this.isoDay,
    this.location,
    this.notes,
  });

  final String title;
  final String isoDay; // YYYY-MM-DD
  final String? location;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'title': title,
    'isoDay': isoDay,
    if (location != null) 'location': location,
    if (notes != null) 'notes': notes,
  };
}

/// `addDeadlineEvent` 返回值（spec §4.1）。
enum CalendarAddResult {
  success,
  fallbackIntentLaunched,
  unsupported,
  failed,
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/core/platform/calendar_deadline_event_test.dart`
Expected: PASS

- [ ] **Step 5: 写失败测试 — addDeadlineEvent 抽象与映射**

仍在 `test/core/platform/calendar_deadline_event_test.dart` 末尾追加：

```dart
test('MethodChannel 实现映射原生返回字符串到 CalendarAddResult', () {
  // 通过 _FakePreparationReminderPlatform 验证接口存在；MethodChannel 行为
  // 由集成/手动验证覆盖，这里只保证类型契约可编译。
  final fake = _FakePlatformForCalendar();
  expect(fake.isSupported, isTrue);
});

class _FakePlatformForCalendar implements PreparationReminderPlatform {
  @override
  Future<CalendarAddResult> addDeadlineEvent(CalendarDeadlineEvent event) async =>
      CalendarAddResult.success;
  @override bool get isSupported => true;
  @override Future<void> syncSnapshot(PreparationReminderSnapshot snapshot) async {}
  @override Future<void> updateSchedule(ReminderPreferences preferences) async {}
  @override Future<ReminderNotificationStatus> getNotificationStatus() async =>
      ReminderNotificationStatus.granted;
  @override Future<ReminderNotificationStatus> requestNotificationPermission() async =>
      ReminderNotificationStatus.granted;
  @override Future<bool> pinWidget() async => false;
  @override Future<void> openNotificationSettings() async {}
  @override Future<String?> takeInitialRoute() async => null;
  @override void setRouteHandler(ReminderRouteHandler? handler) {}
}
```

- [ ] **Step 6: 运行测试确认失败**

Run: `flutter test test/core/platform/calendar_deadline_event_test.dart`
Expected: 编译失败 — `PreparationReminderPlatform.addDeadlineEvent` 未定义。

- [ ] **Step 7: 实现接口方法 + MethodChannel 实现**

在 `lib/core/platform/preparation_reminder_platform.dart`：

1) `PreparationReminderPlatform` 接口在 `Future<bool> pinWidget();` 之后加：

```dart
  Future<CalendarAddResult> addDeadlineEvent(CalendarDeadlineEvent event);
```

2) `MethodChannelPreparationReminderPlatform` 在 `pinWidget` 方法实现之后加：

```dart
  @override
  Future<CalendarAddResult> addDeadlineEvent(CalendarDeadlineEvent event) async {
    if (!isSupported) return CalendarAddResult.unsupported;
    try {
      final result = await _channel.invokeMethod<String>(
        'addDeadlineEvent',
        event.toJson(),
      );
      return _calendarResult(result);
    } catch (_) {
      return CalendarAddResult.failed;
    }
  }

  CalendarAddResult _calendarResult(String? value) => switch (value) {
    'success' => CalendarAddResult.success,
    'fallback' => CalendarAddResult.fallbackIntentLaunched,
    'unsupported' => CalendarAddResult.unsupported,
    _ => CalendarAddResult.failed,
  };
```

- [ ] **Step 8: 运行测试确认通过**

Run: `flutter test test/core/platform/calendar_deadline_event_test.dart`
Expected: PASS（含新接口契约测试）

- [ ] **Step 9: 提交**

```bash
git add lib/core/platform/preparation_reminder_platform.dart test/core/platform/calendar_deadline_event_test.dart
git commit -m "feat(platform): 新增 CalendarDeadlineEvent / addDeadlineEvent 抽象"
```

---

## Task 3: AndroidManifest 权限

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: 无
- Produces: `<uses-permission>` READ_CALENDAR + WRITE_CALENDAR（供 Task 4 原生层使用）

- [ ] **Step 1: 加权限声明**

在 `android/app/src/main/AndroidManifest.xml` 的 `<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>` 之后加：

```xml
    <uses-permission android:name="android.permission.READ_CALENDAR"/>
    <uses-permission android:name="android.permission.WRITE_CALENDAR"/>
```

- [ ] **Step 2: 校验 manifest 合法**

Run: `flutter analyze`（仅确认 Dart 侧无报错；manifest 由 build 时校验）
Expected: 无新增 Dart 报错。

- [ ] **Step 3: 提交**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat(android): 声明 READ/WRITE_CALENDAR 权限"
```

---

## Task 4: Android 原生 addDeadlineEvent 实现

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/scho_navi/MainActivity.kt`

**Interfaces:**
- Consumes: MethodChannel name `com.example.scho_navi/preparation_reminders`（已存在）；方法名 `'addDeadlineEvent'`；参数为 `event.toJson()` 的 Map（title/isoDay/location?/notes?）
- Produces: 原生返回 `'success' | 'fallback' | 'unsupported' | 'failed'`（与 Dart 侧 `_calendarResult` 映射对齐）

- [ ] **Step 1: 实现 Kotlin 分支**

在 `MainActivity.kt`：

1) 顶部 import 区加（如尚无）：

```kotlin
import android.content.ActivityNotFoundException
import android.net.Uri
import android.provider.CalendarContract
import org.json.JSONObject
```

2) `companion object` 内 `NOTIFICATION_PERMISSION_REQUEST` 之后加：

```kotlin
        private const val CALENDAR_PERMISSION_REQUEST = 4107
```

3) 类成员区 `pendingPermissionResult` 之后加：

```kotlin
    private var pendingCalendarPermissionResult: MethodChannel.Result? = null
    private var pendingCalendarEvent: CalendarEventParams? = null
```

4) `handleReminderCall` 的 `when` 内 `"openNotificationSettings"` 之后、`"takeInitialRoute"` 之前加：

```kotlin
                "addDeadlineEvent" -> {
                    val json = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
                    val params = CalendarEventParams.fromArgs(json)
                    if (params == null) {
                        result.error("bad_args", "missing title/isoDay", null)
                        return
                    }
                    addDeadlineEvent(params, result)
                }
```

5) 在 `private fun pinWidget(): Boolean { ... }` 之后加私有方法：

```kotlin
    private data class CalendarEventParams(
        val title: String,
        val isoDay: String,
        val location: String?,
        val notes: String?,
    ) {
        companion object {
            fun fromArgs(args: Map<*, *>): CalendarEventParams? {
                val title = args["title"] as? String
                val isoDay = args["isoDay"] as? String
                if (title == null || isoDay == null) return null
                return CalendarEventParams(
                    title = title,
                    isoDay = isoDay,
                    location = args["location"] as? String,
                    notes = args["notes"] as? String,
                )
            }

            /** ISO 日按 UTC 日历日转全天事件边界（避免非 UTC 时区漂移）。 */
            fun startUtcMs(isoDay: String): Long {
                val (y, m, d) = isoDay.split("-").map { it.toInt() }
                val cal = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC"))
                cal.clear()
                cal.set(y, m - 1, d, 0, 0, 0)
                return cal.timeInMillis
            }
        }
    }

    private fun addDeadlineEvent(params: CalendarEventParams, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            // 低于 23 无运行时权限，直接尝试写入。
            writeToCalendarOrFallback(params, result)
            return
        }
        val granted = checkSelfPermission(Manifest.permission.WRITE_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) {
            writeToCalendarOrFallback(params, result)
            return
        }
        if (pendingCalendarPermissionResult != null) {
            result.error("permission_request_in_progress", "Calendar permission request is already in progress.", null)
            return
        }
        pendingCalendarPermissionResult = result
        pendingCalendarEvent = params
        requestPermissions(
            arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
            CALENDAR_PERMISSION_REQUEST,
        )
    }

    private fun writeToCalendarOrFallback(
        params: CalendarEventParams,
        result: MethodChannel.Result,
    ) {
        val startMs = CalendarEventParams.startUtcMs(params.isoDay)
        val endMs = startMs + 24L * 60 * 60 * 1000
        try {
            val calId = firstWritableCalendarId()
            if (calId != null) {
                val values = ContentValues().apply {
                    put(CalendarContract.Events.TITLE, params.title)
                    put(CalendarContract.Events.DTSTART, startMs)
                    put(CalendarContract.Events.DTEND, endMs)
                    put(CalendarContract.Events.ALL_DAY, 1)
                    put(CalendarContract.Events.EVENT_TIMEZONE, "UTC")
                    put(CalendarContract.Events.CALENDAR_ID, calId)
                    if (params.notes != null) put(CalendarContract.Events.DESCRIPTION, params.notes)
                    if (params.location != null) put(CalendarContract.Events.EVENT_LOCATION, params.location)
                }
                val uri = contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
                if (uri != null) {
                    result.success("success")
                    return
                }
            }
        } catch (_: Exception) {
            // 落入 fallback
        }
        launchInsertIntent(params, startMs, endMs, result)
    }

    private fun firstWritableCalendarId(): Long? {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
        )
        val sel = "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ${CalendarContract.Calendars.CAL_ACCESS_OWNER}"
        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            sel,
            null,
            null,
        )?.use { c ->
            if (c.moveToFirst()) return c.getLong(0)
        }
        return null
    }

    private fun launchInsertIntent(
        params: CalendarEventParams,
        startMs: Long,
        endMs: Long,
        result: MethodChannel.Result,
    ) {
        val intent = Intent(Intent.ACTION_INSERT)
            .setData(CalendarContract.Events.CONTENT_URI)
            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMs)
            .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMs)
            .putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, true)
            .putExtra(CalendarContract.Events.TITLE, params.title)
        if (params.location != null) intent.putExtra(CalendarContract.Events.EVENT_LOCATION, params.location)
        if (params.notes != null) intent.putExtra(CalendarContract.Events.DESCRIPTION, params.notes)
        try {
            startActivity(intent)
            result.success("fallback")
        } catch (_: ActivityNotFoundException) {
            result.success("failed")
        }
    }
```

6) 在 `onRequestPermissionsResult` 内 `if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return` 之后、`pendingPermissionResult?.success(notificationStatus())` 之前加：

```kotlin
        if (requestCode == CALENDAR_PERMISSION_REQUEST) {
            val granted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            val pending = pendingCalendarPermissionResult
            val event = pendingCalendarEvent
            pendingCalendarPermissionResult = null
            pendingCalendarEvent = null
            if (pending == null || event == null) return
            if (granted) {
                writeToCalendarOrFallback(event, pending)
            } else {
                // 拒绝 → 不再直接写入，走 fallback intent
                val startMs = CalendarEventParams.startUtcMs(event.isoDay)
                val endMs = startMs + 24L * 60 * 60 * 1000
                launchInsertIntent(event, startMs, endMs, pending)
            }
            return
        }
```

7) 顶部 import 区如缺 `android.content.ContentValues`，补上：

```kotlin
import android.content.ContentValues
```

- [ ] **Step 2: 编译校验**

Run: `flutter analyze`
Expected: Dart 侧无报错。Kotlin 编译由 `flutter build` 校验；如本地能跑 `./gradlew :app:compileDebugKotlin`（在 `android/` 目录）可提前发现 Kotlin 错误。

- [ ] **Step 3: 提交**

```bash
git add android/app/src/main/kotlin/com/example/scho_navi/MainActivity.kt
git commit -m "feat(android): 原生 addDeadlineEvent 写日历 + fallback intent"
```

---

## Task 5: 截止日卡片组件 PreparationDeadlineCard

**Files:**
- Create: `lib/features/preparation/widgets/preparation_deadline_card.dart`
- Test: `test/features/preparation/widgets/preparation_deadline_card_test.dart`

**Interfaces:**
- Consumes: `BentoTile`, `AppColors`，`CalendarDate`（已有）
- Produces: `PreparationDeadlineCard` widget：
  ```dart
  PreparationDeadlineCard({
    required String label,
    required DateTime? date,
    VoidCallback? onAddToCalendar,
    VoidCallback? onEditDate,
    bool adding = false,
  })
  ```
  - `date == null`：显示「未设置」；不渲染「加入日历」按钮；若 `onEditDate != null` 渲染「设置」TextButton
  - `date != null`：渲染日期 + 「加入日历」IconButton（key `'deadline-add-calendar'`）；报名截止场景下 `onEditDate != null` 时渲染「编辑」TextButton
  - `adding == true`：「加入日历」按钮禁用并显示小转圈

- [ ] **Step 1: 写失败测试**

新建 `test/features/preparation/widgets/preparation_deadline_card_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/preparation/widgets/preparation_deadline_card.dart';

void main() {
  testWidgets('date 为 null 时显示未设置，无加入日历按钮，有设置入口', (t) async {
    var editCalled = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreparationDeadlineCard(
            label: '报名截止',
            date: null,
            onEditDate: () => editCalled++,
          ),
        ),
      ),
    );
    expect(find.text('未设置'), findsOneWidget);
    expect(find.byKey(const Key('deadline-add-calendar')), findsNothing);
    await t.tap(find.text('设置'));
    expect(editCalled, 1);
  });

  testWidgets('date 有值时点加入日历触发回调', (t) async {
    var addCalled = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreparationDeadlineCard(
            label: '提交截止',
            date: DateTime(2026, 9, 1),
            onAddToCalendar: () => addCalled++,
          ),
        ),
      ),
    );
    expect(find.text('2026-09-01'), findsOneWidget);
    await t.tap(find.byKey(const Key('deadline-add-calendar')));
    expect(addCalled, 1);
  });

  testWidgets('adding=true 时加入日历按钮禁用', (t) async {
    var addCalled = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreparationDeadlineCard(
            label: '提交截止',
            date: DateTime(2026, 9, 1),
            adding: true,
            onAddToCalendar: () => addCalled++,
          ),
        ),
      ),
    );
    final btn = t.widget<IconButton>(find.byKey(const Key('deadline-add-calendar')));
    expect(btn.onPressed, isNull);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/preparation/widgets/preparation_deadline_card_test.dart`
Expected: 编译失败 — widget 未定义。

- [ ] **Step 3: 实现 widget**

新建 `lib/features/preparation/widgets/preparation_deadline_card.dart`：

```dart
import 'package:flutter/material.dart';

import '../../../core/calendar_date.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/bento_tile.dart';

/// 关键日期卡片（spec §5.1）：展示报名截止 / 提交截止 / 比赛开始。
///
/// `date == null` 时显示「未设置」，不渲染「加入日历」按钮；若提供
/// [onEditDate] 则渲染「设置」入口，供旧计划补填报名截止。`date` 有值时
/// 渲染「加入日历」IconButton；报名截止场景可额外提供「编辑」入口。
class PreparationDeadlineCard extends StatelessWidget {
  const PreparationDeadlineCard({
    super.key,
    required this.label,
    required this.date,
    this.onAddToCalendar,
    this.onEditDate,
    this.adding = false,
  });

  final String label;
  final DateTime? date;
  final VoidCallback? onAddToCalendar;
  final VoidCallback? onEditDate;
  final bool adding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final hasDate = date != null;
    return BentoTile(
      child: Row(
        children: [
          Icon(
            Icons.event_outlined,
            size: 20,
            color: AppColors.indigo,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoftOf(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasDate ? CalendarDate.toIsoDay(date!) : '未设置',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: hasDate ? scheme.onSurface : AppColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          if (hasDate)
            IconButton(
              key: const Key('deadline-add-calendar'),
              icon: adding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_available_outlined),
              tooltip: '加入日历',
              onPressed: (adding || onAddToCalendar == null) ? null : onAddToCalendar,
            )
          else if (onEditDate != null)
            TextButton(onPressed: onEditDate, child: const Text('设置')),
          if (hasDate && onEditDate != null)
            TextButton(onPressed: onEditDate, child: const Text('编辑')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/preparation/widgets/preparation_deadline_card_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/preparation/widgets/preparation_deadline_card.dart test/features/preparation/widgets/preparation_deadline_card_test.dart
git commit -m "feat(preparation): PreparationDeadlineCard 关键日期卡片"
```

---

## Task 6: 详情页集成卡片 + 加入日历 + 编辑报名截止

**Files:**
- Modify: `lib/features/preparation/pages/preparation_plan_detail_page.dart`
- Test: `test/features/preparation/pages/preparation_plan_detail_page_test.dart`

**Interfaces:**
- Consumes:
  - `PreparationDeadlineCard`（Task 5）
  - `CalendarDeadlineEvent` / `CalendarAddResult`（Task 2）
  - `preparationReminderPlatformProvider`（已存在，`lib/features/preparation/providers/preparation_reminder_providers.dart`）
  - `PreparationPlan.copyWith(registrationDeadline:)` sentinel（Task 1）
  - `showPreparationDatePicker` / `PreparationDatePickerMode.single`（已存在，见 `_changeTargetDate` 用法）
- Produces: 详情页在 `PreparationCountdown` 与 `PreparationPhaseTimeline` 之间渲染两张卡片；点「加入日历」调 platform → SnackBar；「设置/编辑」入口改 `registrationDeadline` 并 `repo.save`

- [ ] **Step 1: 写失败测试**

新建或补充 `test/features/preparation/pages/preparation_plan_detail_page_test.dart`。先看该文件是否已存在；若存在则在 `main()` 内追加测试并复用其 `_plan()`/bootstrap helper，否则新建：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/platform/preparation_reminder_platform.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/domain/entities/preparation_reminder.dart';
import 'package:scho_navi/features/preparation/pages/preparation_plan_detail_page.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';
import 'package:scho_navi/features/preparation/providers/preparation_reminder_providers.dart';

PreparationPlan _plan({DateTime? registrationDeadline}) => PreparationPlan(
  id: 'p1',
  competition: CompetitionSnapshot(
    id: 'c1',
    name: 'ACM-ICPC',
    category: '计算机类',
    rulesSummary: CompetitionRulesSummary(
      signupTime: '',
      contestTime: '',
      teamSize: '',
      format: '',
      organizer: '',
      officialUrl: null,
    ),
  ),
  targetDate: DateTime(2026, 9, 1),
  weeklyCommitment: WeeklyCommitment.hours6to10,
  experienceLevel: ExperienceLevel.beginner,
  status: PreparationPlanStatus.active,
  phases: const [],
  createdAt: DateTime(2026, 6, 28),
  updatedAt: DateTime(2026, 6, 28),
  registrationDeadline: registrationDeadline,
);

class _FakeCalendarPlatform implements PreparationReminderPlatform {
  CalendarAddResult nextResult = CalendarAddResult.success;
  @override
  Future<CalendarAddResult> addDeadlineEvent(CalendarDeadlineEvent event) async => nextResult;
  @override bool get isSupported => true;
  @override Future<void> syncSnapshot(PreparationReminderSnapshot snapshot) async {}
  @override Future<void> updateSchedule(ReminderPreferences preferences) async {}
  @override Future<ReminderNotificationStatus> getNotificationStatus() async => ReminderNotificationStatus.granted;
  @override Future<ReminderNotificationStatus> requestNotificationPermission() async => ReminderNotificationStatus.granted;
  @override Future<bool> pinWidget() async => false;
  @override Future<void> openNotificationSettings() async {}
  @override Future<String?> takeInitialRoute() async => null;
  @override void setRouteHandler(ReminderRouteHandler? handler) {}
}

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('点加入日历成功显示已加入系统日历', (t) async {
    final fake = _FakeCalendarPlatform()..nextResult = CalendarAddResult.success;
    final container = await bootstrap();
    await container.read(preparationPlanRepositoryProvider).save(_plan(registrationDeadline: DateTime(2026, 8, 15)));
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ProviderScope(
          overrides: [preparationReminderPlatformProvider.overrideWithValue(fake)],
          child: MaterialApp(
            home: PreparationPlanDetailPage(planId: 'p1'),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('deadline-add-calendar')).first);
    await t.pumpAndSettle();
    expect(find.text('已加入系统日历'), findsOneWidget);
  });

  testWidgets('unsupported 时显示当前设备不支持', (t) async {
    final fake = _FakeCalendarPlatform()..nextResult = CalendarAddResult.unsupported;
    final container = await bootstrap();
    await container.read(preparationPlanRepositoryProvider).save(_plan(registrationDeadline: DateTime(2026, 8, 15)));
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ProviderScope(
          overrides: [preparationReminderPlatformProvider.overrideWithValue(fake)],
          child: MaterialApp(
            home: PreparationPlanDetailPage(planId: 'p1'),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('deadline-add-calendar')).first);
    await t.pumpAndSettle();
    expect(find.text('当前设备不支持，请手动添加'), findsOneWidget);
  });
}
```

注意：若 `PreparationPlanDetailPage` 已存在构造签名不同，按现有签名调整。若已有同文件，仅追加 `_FakeCalendarPlatform` 与两个 testWidgets，复用其 `_plan()`/bootstrap。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/preparation/pages/preparation_plan_detail_page_test.dart`
Expected: 失败 — 详情页未渲染 `deadline-add-calendar` 按钮（或页面未集成）。

- [ ] **Step 3: 集成详情页**

在 `lib/features/preparation/pages/preparation_plan_detail_page.dart`：

1) 顶部 import 加（如尚无）：

```dart
import '../../../core/calendar_date.dart';
import '../../../core/platform/preparation_reminder_platform.dart';
import '../providers/preparation_reminder_providers.dart';
import '../widgets/preparation_deadline_card.dart';
```

2) `_PreparationPlanDetailPageState` 内 `bool _loading = true;` 之后加：

```dart
  String? _addingLabel;
```

3) `build` 方法 body 的 `ListView.children` 中，`PreparationAnchorBar` 与 `PreparationPhaseTimeline` 之间（即 `const SizedBox(height: 12),` 之后）插入：

```dart
          const SizedBox(height: 12),
          PreparationDeadlineCard(
            label: '报名截止',
            date: plan.registrationDeadline,
            adding: _addingLabel == '报名截止',
            onAddToCalendar: () => _addToCalendar(label: '报名截止', date: plan.registrationDeadline),
            onEditDate: () => _editRegistrationDeadline(),
          ),
          const SizedBox(height: 8),
          PreparationDeadlineCard(
            label: plan.timelineType == CompetitionTimelineType.submission ? '提交截止' : '比赛开始',
            date: plan.targetDate,
            adding: _addingLabel == (plan.timelineType == CompetitionTimelineType.submission ? '提交截止' : '比赛开始'),
            onAddToCalendar: () => _addToCalendar(
              label: plan.timelineType == CompetitionTimelineType.submission ? '提交截止' : '比赛开始',
              date: plan.targetDate,
            ),
          ),
```

（注意原代码已有 `const SizedBox(height: 12)` 在 `PreparationAnchorBar` 之后、`PreparationPhaseTimeline` 之前；把上面这段替换进去，保留后续 `PreparationPhaseTimeline` 的 `const SizedBox(height: 12),` 不变。）

4) 在 `_confirmDelete` 方法之后、`_saveAndRefresh` 之前加：

```dart
  // ── 加入系统日历 / 编辑报名截止 ─────────────────────────────────────────
  Future<void> _addToCalendar({required String label, required DateTime? date}) async {
    if (date == null || _addingLabel != null) return;
    setState(() => _addingLabel = label);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final event = CalendarDeadlineEvent(
        title: '${_plan!.competition.name}·$label',
        isoDay: CalendarDate.toIsoDay(date),
        notes: '由 SchoNavi 备赛计划添加',
      );
      final result =
          await ref.read(preparationReminderPlatformProvider).addDeadlineEvent(event);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(_calendarResultMessage(result))));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('加入日历失败，请稍后重试')));
    } finally {
      if (mounted) setState(() => _addingLabel = null);
    }
  }

  String _calendarResultMessage(CalendarAddResult r) => switch (r) {
    CalendarAddResult.success => '已加入系统日历',
    CalendarAddResult.fallbackIntentLaunched => '已打开日历 App，请确认保存',
    CalendarAddResult.unsupported => '当前设备不支持，请手动添加',
    CalendarAddResult.failed => '加入日历失败，请稍后重试',
  };

  Future<void> _editRegistrationDeadline() async {
    final plan = _plan;
    if (plan == null) return;
    final today = _today;
    final picked = await showPreparationDatePicker(
      context: context,
      mode: PreparationDatePickerMode.single,
      firstDate: today.add(const Duration(days: 1)),
      lastDate: plan.targetDate.subtract(const Duration(days: 1)),
      initial: PreparationDateSelection(single: plan.registrationDeadline ?? plan.targetDate),
    );
    final value = picked?.single;
    if (value == null) return; // 取消
    // 选到的日期若 >= targetDate 视为非法，直接忽略（DatePicker 已约束 lastDate）
    if (!value.isBefore(plan.targetDate)) return;
    final updated = plan.copyWith(registrationDeadline: value);
    await _saveAndRefresh(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('报名截止已更新')));
  }
```

注意：`showPreparationDatePicker` 的 `single` 字段是否可为 null 需对照 `preparation_date_picker.dart`；若 `PreparationDateSelection.single` 必非空，初始值用 `plan.targetDate`（在 lastDate 之外 picker 会自处理）。若 picker 不支持"清空"语义，本次编辑入口只支持设置/改值，不支持清空（清空可后续加）——测试不覆盖清空。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/preparation/pages/preparation_plan_detail_page_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/preparation/pages/preparation_plan_detail_page.dart test/features/preparation/pages/preparation_plan_detail_page_test.dart
git commit -m "feat(preparation): 详情页集成关键日期卡片 + 一键加入系统日历"
```

---

## Task 7: 表单新增报名截止字段

**Files:**
- Modify: `lib/features/preparation/pages/preparation_plan_form_page.dart`
- Test: `test/features/preparation/pages/preparation_plan_form_page_test.dart`

**Interfaces:**
- Consumes: `PreparationPlan.copyWith(registrationDeadline:)`（Task 1）；`showPreparationDatePicker` / `PreparationDatePickerMode.single`（已存在）；`PreparationDateSelection`（已存在）
- Produces: 表单新增可选「报名截止」DatePicker；提交时 `plan.copyWith(registrationDeadline: _registrationDeadline)`；校验 `< targetDate`

- [ ] **Step 1: 写失败测试**

新建或补充 `test/features/preparation/pages/preparation_plan_form_page_test.dart`。先确认是否已存在；若不存在，新建最小测试覆盖报名截止校验：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/pages/preparation_plan_form_page.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';

CompetitionSnapshot _competition() => CompetitionSnapshot(
  id: 'c1',
  name: 'ACM-ICPC',
  category: '计算机类',
  rulesSummary: CompetitionRulesSummary(
    signupTime: '',
    contestTime: '',
    teamSize: '',
    format: '',
    organizer: '',
    officialUrl: null,
  ),
);

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  testWidgets('报名截止行显示并可打开', (t) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: PreparationPlanFormPage(competition: _competition()),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('报名截止'), findsOneWidget);
  });
}
```

（若文件已存在，追加 `expect(find.text('报名截止'), findsOneWidget)` 的 testWidgets。）

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/preparation/pages/preparation_plan_form_page_test.dart`
Expected: 失败 — 「报名截止」行未渲染。

- [ ] **Step 3: 实现表单字段**

在 `lib/features/preparation/pages/preparation_plan_form_page.dart`：

1) `_PreparationPlanFormPageState` 内 `DateTime? _defenseDate;` 之后加：

```dart
  DateTime? _registrationDeadline;
```

2) `_submit` 方法内 `final plan = await ref.read(preparationPlanGeneratorProvider).generate(...)` 之后、`await ref.read(preparationPlanRepositoryProvider).save(plan)` 之前，把 `save(plan)` 改为 `save(plan.copyWith(registrationDeadline: _registrationDeadline))`：

```dart
      final generated = await ref
          .read(preparationPlanGeneratorProvider)
          .generate(
            competition: widget.competition,
            timelineType: _effectiveTimelineType,
            targetDate: _targetDate!,
            eventEndDate: _eventEndDate,
            defenseDate: _defenseDate,
            weeklyCommitment: _weeklyCommitment,
            experienceLevel: _experienceLevel,
            calendarToday: CalendarDate.normalize(DateTime.now()),
            profile: ref.read(profileProvider),
          );
      final plan = generated.copyWith(registrationDeadline: _registrationDeadline);
      await ref.read(preparationPlanRepositoryProvider).save(plan);
```

3) 在 `build` 的「比赛日期」`BentoTile` 与 `if (_dateError != null)` 之间插入报名截止行：

```dart
          const SizedBox(height: 16),
          _sectionLabel('报名截止（可选）'),
          BentoTile(
            onTap: _submitting ? null : _pickRegistrationDeadline,
            child: Row(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  size: 20,
                  color: AppColors.indigo,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _registrationDeadline == null
                        ? '可选，设置后可一键加入日历'
                        : _fmt(_registrationDeadline!),
                    style: TextStyle(
                      color: _registrationDeadline == null
                          ? AppColors.inkFaint
                          : cs.onSurface,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.inkFaint,
                ),
              ],
            ),
          ),
```

4) 在 `_pickDate` 方法之后加：

```dart
  Future<void> _pickRegistrationDeadline() async {
    if (_targetDate == null) {
      setState(() => _dateError = '请先选择比赛日期');
      return;
    }
    final today = CalendarDate.normalize(DateTime.now());
    final picked = await showPreparationDatePicker(
      context: context,
      mode: PreparationDatePickerMode.single,
      firstDate: today.add(const Duration(days: 1)),
      lastDate: _targetDate!.subtract(const Duration(days: 1)),
      initial: PreparationDateSelection(single: _registrationDeadline ?? _targetDate!),
    );
    final value = picked?.single;
    if (value == null) return;
    setState(() => _registrationDeadline = value);
  }
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/preparation/pages/preparation_plan_form_page_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/preparation/pages/preparation_plan_form_page.dart test/features/preparation/pages/preparation_plan_form_page_test.dart
git commit -m "feat(preparation): 创建表单新增报名截止字段"
```

---

## Task 8: 联动验证 + Fake platform 同步 + 收尾

**Files:**
- Verify: 全部上述
- Modify（如需）: 现有 test 中所有 `implements PreparationReminderPlatform` 的 fake（如 `test/features/preparation/pages/preparation_plans_page_test.dart` 的 `_FakePreparationReminderPlatform`）

**Interfaces:**
- Consumes: 全部前序 Task
- Produces: 所有 fake platform 实现 `addDeadlineEvent`；`flutter analyze` + 受影响测试全绿

- [ ] **Step 1: 给现有 fake 补 addDeadlineEvent**

打开 `test/features/preparation/pages/preparation_plans_page_test.dart` 的 `_FakePreparationReminderPlatform`，在 `pinWidget` 方法之后加：

```dart
  @override
  Future<CalendarAddResult> addDeadlineEvent(CalendarDeadlineEvent event) async =>
      CalendarAddResult.success;
```

若其它测试文件也有 `implements PreparationReminderPlatform`，同样补上（用 `grep -rn "implements PreparationReminderPlatform" test`）。

- [ ] **Step 2: dart format 校验**

Run: `dart format --set-exit-if-changed lib test`
Expected: 无变更（exit 0）。若有变更，`dart format lib test` 后回到 Step 1 检查 fake 是否被格式化。

- [ ] **Step 3: flutter analyze**

Run: `flutter analyze`
Expected: 无新增 error/warning。

- [ ] **Step 4: 受影响测试全绿**

Run:
```bash
flutter test test/domain/entities/preparation_plan_test.dart
flutter test test/core/platform/calendar_deadline_event_test.dart
flutter test test/features/preparation/widgets/preparation_deadline_card_test.dart
flutter test test/features/preparation/pages/preparation_plan_detail_page_test.dart
flutter test test/features/preparation/pages/preparation_plan_form_page_test.dart
flutter test test/features/preparation/pages/preparation_plans_page_test.dart
```
Expected: 全部 PASS。

- [ ] **Step 5: 提交（如有 fake 补充）**

```bash
git add test/features/preparation/pages/preparation_plans_page_test.dart
git commit -m "test(preparation): fake platform 补 addDeadlineEvent 实现"
```

若无变更则跳过。

- [ ] **Step 6: 手动验证说明（无法在本会话执行则记录）**

在 Android 设备/模拟器运行 app，备赛详情页：
- 点「加入日历」→ 系统日历 App 出现事件
- 拒绝日历权限后点 → 跳日历 App（fallback intent）
- iOS/Web 上按钮提示不支持

若本地无法验证，明确告知用户哪些步骤未手动验证。

---

## Self-Review

**1. Spec coverage:**
- §2 决策表「覆盖节点=报名截止+目标日期」→ Task 6 卡片渲染两行 + 标签按 `timelineType` ✓
- §3.1 实体 sentinel copyWith → Task 1 ✓
- §3.2 表单校验 + generate 后 copyWith → Task 7 ✓
- §3.3 生成器不推断 → Global Constraints + Task 7 只 copyWith ✓
- §4.1 `CalendarDeadlineEvent` isoDay + `CalendarAddResult` + MethodChannel catch → Task 2 ✓
- §4.2 原生权限 + UTC 边界 + fallback intent → Task 4 ✓
- §4.3 manifest 权限 → Task 3 ✓
- §5.1 卡片 date=null「设置」入口 + date 有值「编辑」 → Task 5 ✓
- §5.2 详情页 `_addToCalendar` + `_editRegistrationDeadline` + 4 种 SnackBar → Task 6 ✓
- §6 错误处理边界 → Task 2/4/6 覆盖（date null/权限拒/无账户/无 App/iOS/Web/异常）✓
- §7 测试清单 → Task 1/2/5/6/7/8 测试 ✓；§7.5 原生层不单测 → Task 8 Step 6 手动 ✓

**2. Placeholder scan:** 无 TBD/TODO；Task 6 Step 3 注释提到"清空可后续加"但 `copyWith` 已支持清空，只是 picker 不支持——这是诚实的范围说明，非占位。Task 4 Kotlin import `ContentValues` 已显式列出。✓

**3. Type consistency:**
- `CalendarDeadlineEvent` 字段名 `title/isoDay/location/notes` → Task 2 定义，Task 6 使用 `isoDay: CalendarDate.toIsoDay(date)` ✓
- `CalendarAddResult` 枚举值 `success/fallbackIntentLaunched/unsupported/failed` → Task 2 定义，Task 6 `_calendarResultMessage` switch 完整 ✓
- `PreparationDeadlineCard` 参数 `label/date/onAddToCalendar/onEditDate/adding` → Task 5 定义，Task 6 调用一致 ✓
- `copyWith(registrationDeadline:)` sentinel → Task 1 定义，Task 6 `_editRegistrationDeadline` 用 `plan.copyWith(registrationDeadline: value)`，Task 7 用 `generated.copyWith(registrationDeadline: _registrationDeadline)` ✓
- MethodChannel 方法名 `'addDeadlineEvent'` + 返回字符串 `'success'/'fallback'/'unsupported'/'failed'` → Task 2 Dart 侧与 Task 4 Kotlin 侧 `result.success("success"/"fallback"/"failed")` 一致；`unsupported` 在 Dart 侧 `isSupported=false` 时返回，Kotlin 不会产生该字符串（Dart 侧已拦截）✓

无问题，plan 可执行。
