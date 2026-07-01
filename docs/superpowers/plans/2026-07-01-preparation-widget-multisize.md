# 备赛桌面小组件多尺寸与视觉升级 · 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将备赛桌面小组件从两档(compact/expanded)升级为四档(Micro/Small/Wide/Hero)自适应布局，冷调玻璃拟态视觉，AlarmManager 30s 自动轮换多计划，跟随系统明暗，并修复 values/colors.xml 调色板缺失 Bug。

**Architecture:** Dart 侧扩展 snapshot 实体新增 `phases` 字段(schemaVersion 1→2，向后兼容)驱动 Hero 阶段轴；Kotlin 侧 `ReminderStorage` 解析新字段，`PreparationWidgetProvider` 按 min_width/min_height 分派四档 layout；新增 `WidgetRotationScheduler` + `WidgetRotationReceiver` 用 `AlarmManager.setRepeating(RTC, 30s)` 触发 `ACTION_ROTATE` 与现有 `ACTION_REFRESH` 分流。

**Tech Stack:** Flutter 3.44.1 / Dart 3.12、Kotlin (JVM17)、Android AppWidget RemoteViews、AlarmManager、minSdk=31(Android 12+)、Riverpod 手写 provider、shared_preferences、drift。

## Global Constraints

- 项目根：`d:/Androidprj/AIGC-LXJH/scho_navi`，分支 `iter4rc2`，所有相对路径基于此根。
- Flutter SDK：`D:/Program Files/Flutter/flutter`（命令 `"D:/Program Files/Flutter/flutter/bin/flutter.bat"`）。Android SDK：`E:/AndroidSDK`，已装 platforms android-31/35/36，minSdk=31。
- 不引入新状态管理/路由/持久化/HTTP 库；保持 Riverpod 手写 provider。
- 视觉令牌单一来源 [lib/core/theme/app_colors.dart](lib/core/theme/app_colors.dart)：indigo `#4F46E5`、cyan `#0891B2`、slate 中性、paper `#F8FAFC`(light)/`#0B1120`(dark)。
- 中文产品文案风格，不改动英文已成型的文件。
- Default to no comments；仅在名称与结构不足以表意时加短注释。
- 测试约定：先写失败测试 → 跑 → 实现 → 跑过 → commit。不 bypass hooks/analyzer/tests。
- snapshot JSON 向后兼容：v1(无 `phases`)解析为空列表，不破坏已安装用户数据。
- 轮换间隔 30s；单计划(`plans.size <= 1`)不轮换。
- 本计划全部为 Dart 实体/服务 + Kotlin + Android 资源，不触碰 LLM 路径。

## File Structure

**Dart 新增/修改：**
- [lib/domain/entities/preparation_reminder.dart](lib/domain/entities/preparation_reminder.dart) — 新增 `ReminderPhaseStatus` enum、`PreparationReminderPhaseSummary` class；`PreparationReminderPlanSummary` 加 `phases` 字段；`schemaVersion` 1→2。
- [lib/domain/services/preparation_reminder_builder.dart](lib/domain/services/preparation_reminder_builder.dart) — `_summary` 计算 `phases`（每阶段 status，截断至 5 段）。
- [test/domain/services/preparation_reminder_builder_test.dart](test/domain/services/preparation_reminder_builder_test.dart) — 扩充 phases 计算用例。
- [test/data/local/preparation_reminder_store_test.dart](test/data/local/preparation_reminder_store_test.dart) — 扩充 snapshot toJson 含 phases + schemaVersion=2。

**Kotlin 新增/修改：**
- [android/app/src/main/kotlin/com/example/scho_navi/ReminderStorage.kt](android/app/src/main/kotlin/com/example/scho_navi/ReminderStorage.kt) — `ReminderPlan` 加 `phases`；新增 `ReminderPhase` data class；`loadSnapshot` 解析 phases(空容错)。
- [android/app/src/main/kotlin/com/example/scho_navi/PreparationWidgetProvider.kt](android/app/src/main/kotlin/com/example/scho_navi/PreparationWidgetProvider.kt) — 四档尺寸分派 + `ACTION_ROTATE` + 阶段轴着色。
- [android/app/src/main/kotlin/com/example/scho_navi/WidgetRotationScheduler.kt](android/app/src/main/kotlin/com/example/scho_navi/WidgetRotationScheduler.kt) — 新文件，AlarmManager 30s 排程 + start/stop。
- [android/app/src/main/kotlin/com/example/scho_navi/MainActivity.kt](android/app/src/main/kotlin/com/example/scho_navi/MainActivity.kt) — syncSnapshot 后按阈值 start/stop 轮换。
- [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) — 注册 `WidgetRotationReceiver`。

**Android 资源新增/修改：**
- `res/layout/preparation_widget_micro.xml` / `_small.xml` / `_wide.xml` / `_hero.xml`（新四档；删 `_compact.xml`/`_expanded.xml`）。
- `res/drawable/preparation_widget_background.xml`（微调日夜间）+ `preparation_widget_progress.xml`（新渐变）+ `preparation_widget_phase_done.xml`/`_active.xml`/`_upcoming.xml`（新阶段轴）。
- `res/values/colors.xml`（补 widget 日间调色板，修 Bug）+ `res/values-night/colors.xml`（保留）。
- `res/xml/preparation_widget_info.xml`（按 spec §4.2 更新参数）。
- `res/values/strings.xml`（description 更新）。

**测试：**
- [test/android_manifest_test.dart](test/android_manifest_test.dart) — 扩充断言：新 receiver、四档 layout 存在、values/colors.xml 含 widget_surface、widget_info 含 minResizeWidth。

---

### Task 1: 修复 values/colors.xml widget 调色板缺失 Bug

**Files:**
- Modify: `android/app/src/main/res/values/colors.xml`
- Test: `test/android_manifest_test.dart`

**Interfaces:**
- Produces: 日间 widget 调色板（`widget_surface`/`widget_border`/`widget_primary`/`widget_secondary`/`widget_accent`/`widget_text_primary`/`widget_text_secondary`/`widget_chip`/`widget_progress_track`），供后续 layout XML 引用。

- [ ] **Step 1: 写失败测试**

在 [test/android_manifest_test.dart](test/android_manifest_test.dart) 末尾 `main` 闭包内新增 test：

```dart
  test('values/colors.xml defines widget palette for light mode', () {
    final colors = File(
      'android/app/src/main/res/values/colors.xml',
    ).readAsStringSync();
    for (final name in [
      'widget_surface',
      'widget_border',
      'widget_primary',
      'widget_secondary',
      'widget_accent',
      'widget_text_primary',
      'widget_text_secondary',
      'widget_chip',
      'widget_progress_track',
    ]) {
      expect(colors, contains('name="$name"'), reason: 'missing $name in light colors');
    }
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"D:/Program Files/Flutter/flutter/bin/flutter.bat" test test/android_manifest_test.dart`
Expected: FAIL，`missing widget_surface in light colors`

- [ ] **Step 3: 补齐日间调色板**

将 `android/app/src/main/res/values/colors.xml` 改为：

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- 原暖白底，保留避免引用断裂，但 launch_background 已改用 splash_paper -->
    <color name="launch_paper">#FBF8F1</color>
    <!-- 冷调底色（= AppColors.paper #F8FAFC），与应用内 splash 动画底色一致 -->
    <color name="splash_paper">#F8FAFC</color>
    <!-- Widget 日间调色板（对齐 AppColors 冷调玻璃拟态） -->
    <color name="widget_surface">#FFFFFF</color>
    <color name="widget_border">#E2E8F0</color>
    <color name="widget_primary">#4F46E5</color>
    <color name="widget_secondary">#0891B2</color>
    <color name="widget_accent">#C2410C</color>
    <color name="widget_text_primary">#0F172A</color>
    <color name="widget_text_secondary">#475569</color>
    <color name="widget_chip">#E0E7FF</color>
    <color name="widget_progress_track">#E2E8F0</color>
</resources>
```

- [ ] **Step 4: 跑测试确认通过**

Run: `"D:/Program Files/Flutter/flutter/bin/flutter.bat" test test/android_manifest_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/res/values/colors.xml test/android_manifest_test.dart
git commit -m "fix(widget): 补齐 values/colors.xml widget 日间调色板缺失"
```

---

### Task 2: Dart 实体扩展 — PreparationReminderPhaseSummary + phases 字段

**Files:**
- Modify: `lib/domain/entities/preparation_reminder.dart`
- Test: `test/data/local/preparation_reminder_store_test.dart`

**Interfaces:**
- Produces: `enum ReminderPhaseStatus { completed, active, upcoming }`；`class PreparationReminderPhaseSummary({title, startDate, endDate, status})` 含 `toJson()`；`PreparationReminderPlanSummary.phases: List<PreparationReminderPhaseSummary>`（默认 `const []`）；`PreparationReminderSnapshot.schemaVersion` 改为 `2`。

- [ ] **Step 1: 写失败测试**

在 [test/data/local/preparation_reminder_store_test.dart](test/data/local/preparation_reminder_store_test.dart) 末尾 `main` 闭包内新增 test：

```dart
  test('snapshot toJson 含 phases 与 schemaVersion=2', () {
    final plan = PreparationReminderPlanSummary(
      planId: 'p1',
      competitionName: '蓝桥杯',
      targetDate: DateTime(2026, 8, 1),
      currentPhase: '冲刺',
      completedTasks: 6,
      totalTasks: 10,
      nextTaskTitle: '刷完 5 道动规',
      nextTaskDueDate: DateTime(2026, 7, 2),
      phases: const [
        PreparationReminderPhaseSummary(
          title: '基础',
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 6, 15),
          status: ReminderPhaseStatus.completed,
        ),
        PreparationReminderPhaseSummary(
          title: '冲刺',
          startDate: DateTime(2026, 6, 25),
          endDate: DateTime(2026, 7, 20),
          status: ReminderPhaseStatus.active,
        ),
      ],
    );
    final snapshot = PreparationReminderSnapshot(
      generatedAt: DateTime(2026, 6, 30),
      currentStreak: 5,
      preparedToday: true,
      lastActivityDay: '2026-06-30',
      plans: [plan],
    );

    final json = snapshot.toJson();

    expect(json['schemaVersion'], 2);
    final planJson = (json['plans'] as List).single as Map<String, dynamic>;
    expect(planJson.containsKey('phases'), isTrue);
    final phases = planJson['phases'] as List;
    expect(phases.length, 2);
    final first = phases.first as Map<String, dynamic>;
    expect(first['title'], '基础');
    expect(first['startDate'], '2026-06-01');
    expect(first['endDate'], '2026-06-15');
    expect(first['status'], 'completed');
  });
```

需在文件顶部 import 已有的 `preparation_reminder.dart`（store_test 已 import，确认无需新增 import）。

- [ ] **Step 2: 跑测试确认失败**

Run: `"D:/Program Files/Flutter/flutter/bin/flutter.bat" test test/data/local/preparation_reminder_store_test.dart --plain-name "snapshot toJson 含 phases 与 schemaVersion=2"`
Expected: FAIL，`PreparationReminderPhaseSummary isn't defined` / `phases isn't a parameter`

- [ ] **Step 3: 扩展实体**

在 [lib/domain/entities/preparation_reminder.dart](lib/domain/entities/preparation_reminder.dart) 中：

a) `ReminderNotificationStatus` enum 上方新增 enum 与 class：

```dart
enum ReminderPhaseStatus { completed, active, upcoming }

class PreparationReminderPhaseSummary {
  const PreparationReminderPhaseSummary({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final ReminderPhaseStatus status;

  Map<String, dynamic> toJson() => {
    'title': title,
    'startDate': _isoDay(startDate),
    'endDate': _isoDay(endDate),
    'status': status.name,
  };
}
```

b) `PreparationReminderPlanSummary` 构造函数加 `this.phases = const []`，字段加 `final List<PreparationReminderPhaseSummary> phases;`，`toJson` 加 `'phases': phases.map((p) => p.toJson()).toList(growable: false),`。

c) `PreparationReminderSnapshot.schemaVersion` 由 `1` 改为 `2`。

- [ ] **Step 4: 跑测试确认通过**

Run: `"D:/Program Files/Flutter/flutter/bin/flutter.bat" test test/data/local/preparation_reminder_store_test.dart`
Expected: PASS（含原有两个 + 新增一个）

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/preparation_reminder.dart test/data/local/preparation_reminder_store_test.dart
git commit -m "feat(reminder): snapshot 实体加 phases 字段并升 schemaVersion=2"
```

---

### Task 3: Builder 计算 phases status

**Files:**
- Modify: `lib/domain/services/preparation_reminder_builder.dart`
- Test: `test/domain/services/preparation_reminder_builder_test.dart`

**Interfaces:**
- Consumes: `PreparationReminderPlanSummary.phases`（Task 2 产出）；`PreparationPhase` 实体（`startDate`/`endDate`/`title`）。
- Produces: `builder.build()` 产出的 `PreparationReminderPlanSummary.phases` 按阶段 status 填充，最多 5 段。

- [ ] **Step 1: 写失败测试**

在 [test/domain/services/preparation_reminder_builder_test.dart](test/domain/services/preparation_reminder_builder_test.dart) 中：

a) 修改顶部 `plan(...)` helper，让它支持 `phases` 参数（替换现有写死的单阶段）：

```dart
PreparationPlan plan({
  required String id,
  required DateTime targetDate,
  PreparationPlanStatus status = PreparationPlanStatus.active,
  List<PreparationTask>? tasks,
  List<PreparationPhase>? phases,
}) => PreparationPlan(
  id: id,
  competition: CompetitionSnapshot(
    id: 'c_$id',
    name: '竞赛 $id',
    category: '计算机类',
    rulesSummary: const CompetitionRulesSummary(
      signupTime: '',
      contestTime: '',
      teamSize: '',
      format: '',
      organizer: '',
    ),
  ),
  targetDate: targetDate,
  weeklyCommitment: WeeklyCommitment.hours6to10,
  experienceLevel: ExperienceLevel.beginner,
  status: status,
  phases: phases ??
      [
        PreparationPhase(
          key: 'phase',
          title: '强化训练',
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 7, 31),
          tasks: tasks ?? const [],
        ),
      ],
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 1),
);
```

b) 在 `main` 闭包末尾新增 test：

```dart
  test('phases 按今天计算 completed/active/upcoming 状态', () {
    final snapshot = builder.build(
      plans: [
        plan(
          id: 'p1',
          targetDate: DateTime(2026, 8, 1),
          phases: [
            PreparationPhase(
              key: 'base',
              title: '基础',
              startDate: DateTime(2026, 6, 1),
              endDate: DateTime(2026, 6, 15),
              tasks: const [],
            ),
            PreparationPhase(
              key: 'sprint',
              title: '冲刺',
              startDate: DateTime(2026, 6, 25),
              endDate: DateTime(2026, 7, 20),
              tasks: const [],
            ),
            PreparationPhase(
              key: 'mock',
              title: '模拟',
              startDate: DateTime(2026, 7, 21),
              endDate: DateTime(2026, 7, 31),
              tasks: const [],
            ),
          ],
        ),
      ],
      activityDays: const {},
      now: now,
    );

    final phases = snapshot.plans.single.phases;
    expect(phases.map((p) => p.title), ['基础', '冲刺', '模拟']);
    expect(phases[0].status, ReminderPhaseStatus.completed);
    expect(phases[1].status, ReminderPhaseStatus.active);
    expect(phases[2].status, ReminderPhaseStatus.upcoming);
  });

  test('phases 超过 5 段时截断为 5 段', () {
    final many = List.generate(7, (i) => PreparationPhase(
      key: 'p$i',
      title: '阶段$i',
      startDate: DateTime(2026, 6, 1 + i * 5),
      endDate: DateTime(2026, 6, 5 + i * 5),
      tasks: const [],
    ));
    final snapshot = builder.build(
      plans: [plan(id: 'p1', targetDate: DateTime(2026, 8, 1), phases: many)],
      activityDays: const {},
      now: now,
    );
    expect(snapshot.plans.single.phases.length, 5);
  });
```

需在文件顶部 import：`import 'package:scho_navi/domain/entities/preparation_reminder.dart';`（确认现有 import 行已含 `preparation_plan.dart`，需新增 `preparation_reminder.dart` 以引用 `ReminderPhaseStatus`）。

- [ ] **Step 2: 跑测试确认失败**

Run: `"D:/Program Files/Flutter/flutter/bin/flutter.bat" test test/domain/services/preparation_reminder_builder_test.dart`
Expected: FAIL，`phases` 为空列表 / 长度不符

- [ ] **Step 3: 实现 builder phases 计算**

在 [lib/domain/services/preparation_reminder_builder.dart](lib/domain/services/preparation_reminder_builder.dart) 中：

a) 顶部 import 加 `preparation_reminder.dart`：

```dart
import '../entities/preparation_plan.dart';
import '../entities/preparation_reminder.dart';
```
（确认第二行不存在则新增）

b) `_summary` 方法返回的 `PreparationReminderPlanSummary` 加 `phases` 参数。在 `_summary` 内、`return PreparationReminderPlanSummary(` 之前插入阶段计算：

```dart
    final phaseSummaries = plan.phases.take(5).map((phase) {
      final start = _day(phase.startDate);
      final end = _day(phase.endDate);
      final ReminderPhaseStatus status;
      if (today.isAfter(end)) {
        status = ReminderPhaseStatus.completed;
      } else if (today.isBefore(start)) {
        status = ReminderPhaseStatus.upcoming;
      } else {
        status = ReminderPhaseStatus.active;
      }
      return PreparationReminderPhaseSummary(
        title: phase.title,
        startDate: phase.startDate,
        endDate: phase.endDate,
        status: status,
      );
    }).toList(growable: false);
```

c) 在 `return PreparationReminderPlanSummary(...)` 调用末尾加 `phases: phaseSummaries,`。

- [ ] **Step 4: 跑测试确认通过**

Run: `"D:/Program Files/Flutter/flutter/bin/flutter.bat" test test/domain/services/preparation_reminder_builder_test.dart`
Expected: PASS（含原有 3 个 + 新增 2 个）

- [ ] **Step 5: Commit**

```bash
git add lib/domain/services/preparation_reminder_builder.dart test/domain/services/preparation_reminder_builder_test.dart
git commit -m "feat(reminder): builder 计算 phases 状态并截断至 5 段"
```

---

### Task 4: Kotlin ReminderStorage 解析 phases + ReminderPhase

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/scho_navi/ReminderStorage.kt`
- Test: 手动验证（Kotlin 单测未配置，依赖集成测试与 manifest 测试间接覆盖）

**Interfaces:**
- Consumes: `MainActivity.syncSnapshot` 传入的 v2 JSON（含 `phases` 数组）。
- Produces: `ReminderPlan.phases: List<ReminderPhase>`；`ReminderPhase(title, startDate, endDate, status)`。v1 JSON（无 phases）解析为空列表。

- [ ] **Step 1: 新增 ReminderPhase data class 与 ReminderPlan.phases**

在 [android/app/src/main/kotlin/com/example/scho_navi/ReminderStorage.kt](android/app/src/main/kotlin/com/example/scho_navi/ReminderStorage.kt) 中：

a) 在 `ReminderPlan` data class 上方新增：

```kotlin
data class ReminderPhase(
    val title: String,
    val startDate: String,
    val endDate: String,
    val status: String,
)
```

b) `ReminderPlan` 加 `val phases: List<ReminderPhase> = emptyList()` 字段（放最后，带默认值兼容现有调用）。

- [ ] **Step 2: loadSnapshot 解析 phases**

在 `loadSnapshot` 的 `buildList` 循环里，构造 `ReminderPlan` 时加 phases 解析。将 `add(ReminderPlan(...))` 改为：

```kotlin
                        val phasesJson = item.optJSONArray("phases")
                        val phases = buildList {
                            if (phasesJson != null) {
                                for (pi in 0 until phasesJson.length()) {
                                    val ph = phasesJson.optJSONObject(pi) ?: continue
                                    add(
                                        ReminderPhase(
                                            title = ph.optString("title"),
                                            startDate = ph.optString("startDate"),
                                            endDate = ph.optString("endDate"),
                                            status = ph.optString("status", "upcoming"),
                                        ),
                                    )
                                }
                            }
                        }
                        add(
                            ReminderPlan(
                                planId = item.optString("planId"),
                                competitionName = item.optString("competitionName"),
                                targetDate = item.optString("targetDate"),
                                currentPhase = item.optString("currentPhase"),
                                completedTasks = item.optInt("completedTasks"),
                                totalTasks = item.optInt("totalTasks"),
                                nextTaskTitle = item.optString("nextTaskTitle").ifBlank { null },
                                nextTaskDueDate = item.optString("nextTaskDueDate").ifBlank { null },
                                phases = phases,
                            ),
                        )
```

`schemaVersion` 检查保持 `!= 1` 时返回空 —— 但 v2 也要通过。改为接受 1 或 2：

```kotlin
            val schema = root.optInt("schemaVersion", 0)
            if (schema !in 1..2) return ReminderSnapshot(0, null, emptyList())
```

- [ ] **Step 3: 编译验证**

Run: `cd android && ./gradlew :app:compileDebugKotlin 2>&1 | tail -20`（若无可执行 gradlew，用 `cd android && "D:/Program Files/Flutter/flutter/bin/flutter.bat" build apk --debug 2>&1 | tail -30` 间接编译）
Expected: BUILD SUCCESSFUL，无未解析引用。

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/example/scho_navi/ReminderStorage.kt
git commit -m "feat(widget): ReminderStorage 解析 phases 字段并兼容 schema v1/v2"
```

---

### Task 5: 四档 layout XML + drawable 资源

**Files:**
- Create: `android/app/src/main/res/layout/preparation_widget_micro.xml`
- Create: `android/app/src/main/res/layout/preparation_widget_small.xml`
- Create: `android/app/src/main/res/layout/preparation_widget_wide.xml`
- Create: `android/app/src/main/res/layout/preparation_widget_hero.xml`
- Delete: `android/app/src/main/res/layout/preparation_widget_compact.xml`
- Delete: `android/app/src/main/res/layout/preparation_widget_expanded.xml`
- Create: `android/app/src/main/res/drawable/preparation_widget_progress.xml`
- Create: `android/app/src/main/res/drawable/preparation_widget_phase_done.xml`
- Create: `android/app/src/main/res/drawable/preparation_widget_phase_active.xml`
- Create: `android/app/src/main/res/drawable/preparation_widget_phase_upcoming.xml`
- Modify: `android/app/src/main/res/drawable/preparation_widget_background.xml`
- Modify: `android/app/src/main/res/values/strings.xml`
- Test: `test/android_manifest_test.dart`

**Interfaces:**
- Produces: 四档 layout（id 命名见各档）；共用 `widget_root`/`widget_content_group`/`widget_empty_group`/`widget_empty_title`/`widget_empty_action` id；进度用 `widget_progress`(ProgressBar)；阶段轴用 `widget_phase_0`..`widget_phase_4` + `widget_phase_label_0`..`widget_phase_label_4`。

- [ ] **Step 1: 写资源存在性测试**

在 [test/android_manifest_test.dart](test/android_manifest_test.dart) `main` 闭包末尾新增：

```dart
  test('four widget layout files exist', () {
    for (final name in [
      'preparation_widget_micro',
      'preparation_widget_small',
      'preparation_widget_wide',
      'preparation_widget_hero',
    ]) {
      final file = File('android/app/src/main/res/layout/$name.xml');
      expect(file.existsSync(), isTrue, reason: 'missing layout $name.xml');
    }
    expect(
      File('android/app/src/main/res/layout/preparation_widget_compact.xml').existsSync(),
      isFalse,
      reason: 'compact.xml should be removed',
    );
    expect(
      File('android/app/src/main/res/layout/preparation_widget_expanded.xml').existsSync(),
      isFalse,
      reason: 'expanded.xml should be removed',
    );
  });

  test('widget_info declares resize bounds', () {
    final info = File(
      'android/app/src/main/res/xml/preparation_widget_info.xml',
    ).readAsStringSync();
    expect(info, contains('android:minResizeWidth'));
    expect(info, contains('android:minResizeHeight'));
    expect(info, contains('android:targetCellWidth'));
    expect(info, contains('android:targetCellHeight'));
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"D:/Program Files/Flutter/flutter/bin/flutter.bat" test test/android_manifest_test.dart`
Expected: FAIL，`missing layout preparation_widget_micro.xml`

- [ ] **Step 3: 新增渐变进度 drawable**

创建 `android/app/src/main/res/drawable/preparation_widget_progress.xml`：

```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:id="@android:id/background">
        <shape android:shape="rectangle">
            <solid android:color="@color/widget_progress_track" />
            <corners android:radius="999dp" />
        </shape>
    </item>
    <item android:id="@android:id/progress">
        <clip>
            <shape android:shape="rectangle">
                <gradient
                    android:angle="0"
                    android:startColor="@color/widget_primary"
                    android:endColor="@color/widget_secondary" />
                <corners android:radius="999dp" />
            </shape>
        </clip>
    </item>
</layer-list>
```

- [ ] **Step 4: 新增阶段轴 drawable**

`preparation_widget_phase_done.xml`：

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:angle="0" android:startColor="@color/widget_primary" android:endColor="@color/widget_secondary" />
    <corners android:radius="999dp" />
</shape>
```

`preparation_widget_phase_active.xml`：

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:angle="0" android:startColor="@color/widget_primary" android:endColor="@color/widget_secondary" />
    <corners android:radius="999dp" />
    <stroke android:width="1dp" android:color="@color/widget_primary" />
</shape>
```

`preparation_widget_phase_upcoming.xml`：

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="@color/widget_progress_track" />
    <corners android:radius="999dp" />
</shape>
```

- [ ] **Step 5: 微调背景 drawable**

将 `android/app/src/main/res/drawable/preparation_widget_background.xml` 改为支持日夜间（用 `?android:attr/colorBackground` 不够精确，直接用 resource 引用，values/values-night 各自解析）：

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="@color/widget_surface" />
    <stroke android:width="1dp" android:color="@color/widget_border" />
    <corners android:radius="22dp" />
</shape>
```

（`widget_surface` 在 values=白、values-night=`#172033`，已由 Task 1 + 现有 night 文件保证。）

- [ ] **Step 6: 新增 Micro layout**

创建 `android/app/src/main/res/layout/preparation_widget_micro.xml`：

```xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/preparation_widget_background"
    android:clickable="true"
    android:focusable="true"
    android:padding="10dp">

    <LinearLayout
        android:id="@+id/widget_content_group"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:orientation="vertical">

        <TextView
            android:id="@+id/widget_competition"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:ellipsize="end"
            android:fontFamily="sans"
            android:maxLines="1"
            android:textColor="@color/widget_text_primary"
            android:textSize="13sp"
            android:textStyle="bold" />

        <TextView
            android:id="@+id/widget_countdown"
            android:layout_width="wrap_content"
            android:layout_height="0dp"
            android:layout_weight="1"
            android:fontFamily="sans"
            android:gravity="center_vertical"
            android:textColor="@color/widget_primary"
            android:textSize="28sp"
            android:textStyle="bold" />

        <ProgressBar
            android:id="@+id/widget_progress"
            style="?android:attr/progressBarStyleHorizontal"
            android:layout_width="match_parent"
            android:layout_height="4dp"
            android:max="100"
            android:progress="0"
            android:progressDrawable="@drawable/preparation_widget_progress" />

        <TextView
            android:id="@+id/widget_progress_text"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="2dp"
            android:fontFamily="sans"
            android:textColor="@color/widget_text_secondary"
            android:textSize="9sp" />
    </LinearLayout>

    <LinearLayout
        android:id="@+id/widget_empty_group"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:gravity="center"
        android:orientation="vertical"
        android:visibility="gone">

        <TextView
            android:id="@+id/widget_empty_title"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:gravity="center"
            android:textColor="@color/widget_text_primary"
            android:textSize="12sp"
            android:textStyle="bold" />

        <TextView
            android:id="@+id/widget_empty_action"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="4dp"
            android:gravity="center"
            android:textColor="@color/widget_primary"
            android:textSize="10sp"
            android:textStyle="bold" />
    </LinearLayout>
</FrameLayout>
```

- [ ] **Step 7: 新增 Small layout**

创建 `android/app/src/main/res/layout/preparation_widget_small.xml`（基于现有 expanded 精简，保留 competition/position/countdown/phase/next_task/due/progress/progress_text/streak）：

```xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/preparation_widget_background"
    android:clickable="true"
    android:focusable="true"
    android:padding="12dp">

    <LinearLayout
        android:id="@+id/widget_content_group"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:orientation="vertical">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:gravity="center_vertical"
            android:orientation="horizontal">

            <TextView
                android:id="@+id/widget_competition"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:ellipsize="end"
                android:fontFamily="sans"
                android:maxLines="1"
                android:textColor="@color/widget_text_primary"
                android:textSize="14sp"
                android:textStyle="bold" />

            <TextView
                android:id="@+id/widget_position"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:background="@drawable/preparation_widget_chip"
                android:fontFamily="sans"
                android:paddingHorizontal="7dp"
                android:paddingVertical="2dp"
                android:textColor="@color/widget_primary"
                android:textSize="9sp"
                android:textStyle="bold" />
        </LinearLayout>

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="3dp"
            android:gravity="center_vertical"
            android:orientation="horizontal">

            <TextView
                android:id="@+id/widget_countdown"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:fontFamily="sans"
                android:textColor="@color/widget_primary"
                android:textSize="20sp"
                android:textStyle="bold" />

            <TextView
                android:id="@+id/widget_phase"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_marginStart="8dp"
                android:layout_weight="1"
                android:ellipsize="end"
                android:fontFamily="sans"
                android:maxLines="1"
                android:textColor="@color/widget_text_secondary"
                android:textSize="10sp" />
        </LinearLayout>

        <TextView
            android:id="@+id/widget_next_task"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="3dp"
            android:ellipsize="end"
            android:fontFamily="sans"
            android:maxLines="1"
            android:textColor="@color/widget_text_primary"
            android:textSize="11sp"
            android:textStyle="bold" />

        <TextView
            android:id="@+id/widget_due"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:fontFamily="sans"
            android:textColor="@color/widget_text_secondary"
            android:textSize="9sp" />

        <View
            android:layout_width="match_parent"
            android:layout_height="0dp"
            android:layout_weight="1" />

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:gravity="center_vertical"
            android:orientation="horizontal">

            <ProgressBar
                android:id="@+id/widget_progress"
                style="?android:attr/progressBarStyleHorizontal"
                android:layout_width="0dp"
                android:layout_height="5dp"
                android:layout_weight="1"
                android:progressDrawable="@drawable/preparation_widget_progress" />

            <TextView
                android:id="@+id/widget_progress_text"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginStart="6dp"
                android:fontFamily="sans"
                android:textColor="@color/widget_text_secondary"
                android:textSize="9sp" />
        </LinearLayout>

        <TextView
            android:id="@+id/widget_streak"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="3dp"
            android:drawableStart="@drawable/ic_widget_streak"
            android:drawablePadding="3dp"
            android:ellipsize="end"
            android:fontFamily="sans"
            android:maxLines="1"
            android:textColor="@color/widget_accent"
            android:textSize="9sp"
            android:textStyle="bold" />
    </LinearLayout>

    <LinearLayout
        android:id="@+id/widget_empty_group"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:gravity="center"
        android:orientation="vertical"
        android:visibility="gone">

        <TextView
            android:id="@+id/widget_empty_title"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:gravity="center"
            android:textColor="@color/widget_text_primary"
            android:textSize="13sp"
            android:textStyle="bold" />

        <TextView
            android:id="@+id/widget_empty_action"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="5dp"
            android:gravity="center"
            android:textColor="@color/widget_primary"
            android:textSize="10sp"
            android:textStyle="bold" />
    </LinearLayout>
</FrameLayout>
```

- [ ] **Step 8: 新增 Wide layout**

创建 `android/app/src/main/res/layout/preparation_widget_wide.xml`（左右双栏，右栏进度用 ProgressBar 横条 + 百分比文字 —— 进度环见 Task 8 风险缓解，先用横条）：

```xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/preparation_widget_background"
    android:clickable="true"
    android:focusable="true"
    android:padding="14dp">

    <LinearLayout
        android:id="@+id/widget_content_group"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:orientation="horizontal"
        android:baselineAligned="false">

        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="match_parent"
            android:layout_weight="38"
            android:orientation="vertical">

            <LinearLayout
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:gravity="center_vertical"
                android:orientation="horizontal">

                <TextView
                    android:id="@+id/widget_competition"
                    android:layout_width="0dp"
                    android:layout_height="wrap_content"
                    android:layout_weight="1"
                    android:ellipsize="end"
                    android:fontFamily="sans"
                    android:maxLines="1"
                    android:textColor="@color/widget_text_primary"
                    android:textSize="14sp"
                    android:textStyle="bold" />

                <TextView
                    android:id="@+id/widget_position"
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:layout_marginStart="6dp"
                    android:background="@drawable/preparation_widget_chip"
                    android:fontFamily="sans"
                    android:paddingHorizontal="7dp"
                    android:paddingVertical="2dp"
                    android:textColor="@color/widget_primary"
                    android:textSize="9sp"
                    android:textStyle="bold" />
            </LinearLayout>

            <TextView
                android:id="@+id/widget_countdown"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginTop="4dp"
                android:fontFamily="sans"
                android:textColor="@color/widget_primary"
                android:textSize="22sp"
                android:textStyle="bold" />

            <TextView
                android:id="@+id/widget_phase"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginTop="2dp"
                android:fontFamily="sans"
                android:textColor="@color/widget_text_secondary"
                android:textSize="10sp" />

            <View
                android:layout_width="match_parent"
                android:layout_height="0dp"
                android:layout_weight="1" />

            <TextView
                android:id="@+id/widget_streak"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:drawableStart="@drawable/ic_widget_streak"
                android:drawablePadding="3dp"
                android:ellipsize="end"
                android:fontFamily="sans"
                android:maxLines="1"
                android:textColor="@color/widget_accent"
                android:textSize="9sp"
                android:textStyle="bold" />
        </LinearLayout>

        <View
            android:layout_width="1dp"
            android:layout_height="match_parent"
            android:layout_marginStart="12dp"
            android:background="@color/widget_border" />

        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="match_parent"
            android:layout_marginStart="12dp"
            android:layout_weight="62"
            android:orientation="vertical">

            <TextView
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:fontFamily="sans"
                android:text="下一任务"
                android:textColor="@color/widget_text_secondary"
                android:textSize="9sp" />

            <TextView
                android:id="@+id/widget_next_task"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:layout_marginTop="2dp"
                android:ellipsize="end"
                android:fontFamily="sans"
                android:maxLines="2"
                android:textColor="@color/widget_text_primary"
                android:textSize="12sp"
                android:textStyle="bold" />

            <TextView
                android:id="@+id/widget_due"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:fontFamily="sans"
                android:textColor="@color/widget_text_secondary"
                android:textSize="9sp" />

            <View
                android:layout_width="match_parent"
                android:layout_height="0dp"
                android:layout_weight="1" />

            <ProgressBar
                android:id="@+id/widget_progress"
                style="?android:attr/progressBarStyleHorizontal"
                android:layout_width="match_parent"
                android:layout_height="6dp"
                android:progressDrawable="@drawable/preparation_widget_progress" />

            <TextView
                android:id="@+id/widget_progress_text"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginTop="2dp"
                android:fontFamily="sans"
                android:textColor="@color/widget_text_secondary"
                android:textSize="9sp" />
        </LinearLayout>
    </LinearLayout>

    <LinearLayout
        android:id="@+id/widget_empty_group"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:gravity="center"
        android:orientation="vertical"
        android:visibility="gone">

        <TextView
            android:id="@+id/widget_empty_title"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:gravity="center"
            android:textColor="@color/widget_text_primary"
            android:textSize="13sp"
            android:textStyle="bold" />

        <TextView
            android:id="@+id/widget_empty_action"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="5dp"
            android:gravity="center"
            android:textColor="@color/widget_primary"
            android:textSize="10sp"
            android:textStyle="bold" />
    </LinearLayout>
</FrameLayout>
```

- [ ] **Step 9: 新增 Hero layout**

创建 `android/app/src/main/res/layout/preparation_widget_hero.xml`（主视觉大倒计时 + 横条进度 + 5 段阶段轴）。阶段轴用 5 个 View（`widget_phase_0`..`widget_phase_4`）+ 5 个 TextView（`widget_phase_label_0`..`widget_phase_label_4`），运行时按状态设 background drawable 并隐藏多余段：

```xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/preparation_widget_background"
    android:clickable="true"
    android:focusable="true"
    android:padding="16dp">

    <LinearLayout
        android:id="@+id/widget_content_group"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:orientation="vertical">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:gravity="center_vertical"
            android:orientation="horizontal">

            <TextView
                android:id="@+id/widget_competition"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:ellipsize="end"
                android:fontFamily="sans"
                android:maxLines="1"
                android:textColor="@color/widget_text_primary"
                android:textSize="15sp"
                android:textStyle="bold" />

            <TextView
                android:id="@+id/widget_position"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginStart="6dp"
                android:background="@drawable/preparation_widget_chip"
                android:fontFamily="sans"
                android:paddingHorizontal="7dp"
                android:paddingVertical="2dp"
                android:textColor="@color/widget_primary"
                android:textSize="9sp"
                android:textStyle="bold" />
        </LinearLayout>

        <TextView
            android:id="@+id/widget_streak"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="2dp"
            android:drawableStart="@drawable/ic_widget_streak"
            android:drawablePadding="3dp"
            android:ellipsize="end"
            android:fontFamily="sans"
            android:maxLines="1"
            android:textColor="@color/widget_accent"
            android:textSize="10sp"
            android:textStyle="bold" />

        <TextView
            android:id="@+id/widget_countdown"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="8dp"
            android:fontFamily="sans"
            android:textColor="@color/widget_primary"
            android:textSize="42sp"
            android:textStyle="bold" />

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="8dp"
            android:gravity="center_vertical"
            android:orientation="horizontal">

            <ProgressBar
                android:id="@+id/widget_progress"
                style="?android:attr/progressBarStyleHorizontal"
                android:layout_width="0dp"
                android:layout_height="6dp"
                android:layout_weight="1"
                android:progressDrawable="@drawable/preparation_widget_progress" />

            <TextView
                android:id="@+id/widget_progress_text"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginStart="8dp"
                android:fontFamily="sans"
                android:textColor="@color/widget_text_secondary"
                android:textSize="11sp"
                android:textStyle="bold" />
        </LinearLayout>

        <View
            android:layout_width="match_parent"
            android:layout_height="0dp"
            android:layout_weight="1" />

        <LinearLayout
            android:id="@+id/widget_phase_row"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal">

            <View
                android:id="@+id/widget_phase_0"
                android:layout_width="0dp"
                android:layout_height="5dp"
                android:layout_weight="1"
                android:background="@drawable/preparation_widget_phase_upcoming" />

            <View
                android:id="@+id/widget_phase_1"
                android:layout_width="0dp"
                android:layout_height="5dp"
                android:layout_weight="1"
                android:layout_marginStart="4dp"
                android:background="@drawable/preparation_widget_phase_upcoming" />

            <View
                android:id="@+id/widget_phase_2"
                android:layout_width="0dp"
                android:layout_height="5dp"
                android:layout_weight="1"
                android:layout_marginStart="4dp"
                android:background="@drawable/preparation_widget_phase_upcoming" />

            <View
                android:id="@+id/widget_phase_3"
                android:layout_width="0dp"
                android:layout_height="5dp"
                android:layout_weight="1"
                android:layout_marginStart="4dp"
                android:background="@drawable/preparation_widget_phase_upcoming" />

            <View
                android:id="@+id/widget_phase_4"
                android:layout_width="0dp"
                android:layout_height="5dp"
                android:layout_weight="1"
                android:layout_marginStart="4dp"
                android:background="@drawable/preparation_widget_phase_upcoming" />
        </LinearLayout>

        <LinearLayout
            android:id="@+id/widget_phase_label_row"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="4dp"
            android:orientation="horizontal">

            <TextView
                android:id="@+id/widget_phase_label_0"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:ellipsize="end"
                android:fontFamily="sans"
                android:maxLines="1"
                android:textColor="@color/widget_text_secondary"
                android:textSize="8sp" />

            <TextView
                android:id="@+id/widget_phase_label_1"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:ellipsize="end"
                android:fontFamily="sans"
                android:maxLines="1"
                android:textColor="@color/widget_text_secondary"
                android:textSize="8sp" />

            <TextView
                android:id="@+id/widget_phase_label_2"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:ellipsize="end"
                android:fontFamily="sans"
                android:maxLines="1"
                android:textColor="@color/widget_text_secondary"
                android:textSize="8sp" />

            <TextView
                android:id="@+id/widget_phase_label_3"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:ellipsize="end"
                android:fontFamily="sans"
                android:maxLines="1"
                android:textColor="@color/widget_text_secondary"
                android:textSize="8sp" />

            <TextView
                android:id="@+id/widget_phase_label_4"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:ellipsize="end"
                android:fontFamily="sans"
                android:maxLines="1"
                android:textColor="@color/widget_text_secondary"
                android:textSize="8sp" />
        </LinearLayout>

        <TextView
            android:id="@+id/widget_next_task"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="6dp"
            android:ellipsize="end"
            android:fontFamily="sans"
            android:maxLines="1"
            android:textColor="@color/widget_text_primary"
            android:textSize="12sp"
            android:textStyle="bold" />

        <TextView
            android:id="@+id/widget_due"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:fontFamily="sans"
            android:textColor="@color/widget_text_secondary"
            android:textSize="9sp" />
    </LinearLayout>

    <LinearLayout
        android:id="@+id/widget_empty_group"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:gravity="center"
        android:orientation="vertical"
        android:visibility="gone">

        <TextView
            android:id="@+id/widget_empty_title"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:gravity="center"
            android:textColor="@color/widget_text_primary"
            android:textSize="14sp"
            android:textStyle="bold" />

        <TextView
            android:id="@+id/widget_empty_action"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="6dp"
            android:gravity="center"
            android:textColor="@color/widget_primary"
            android:textSize="11sp"
            android:textStyle="bold" />
    </LinearLayout>
</FrameLayout>
```

- [ ] **Step 10: 删除旧 compact/expanded layout**

```bash
rm android/app/src/main/res/layout/preparation_widget_compact.xml
rm android/app/src/main/res/layout/preparation_widget_expanded.xml
```

- [ ] **Step 11: 更新 widget_info.xml**

将 `android/app/src/main/res/xml/preparation_widget_info.xml` 改为：

```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/preparation_widget_description"
    android:initialLayout="@layout/preparation_widget_small"
    android:minWidth="120dp"
    android:minHeight="100dp"
    android:minResizeWidth="100dp"
    android:minResizeHeight="100dp"
    android:maxResizeWidth="480dp"
    android:maxResizeHeight="420dp"
    android:previewLayout="@layout/preparation_widget_hero"
    android:resizeMode="horizontal|vertical"
    android:targetCellWidth="2"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:widgetCategory="home_screen" />
```

- [ ] **Step 12: 更新 strings.xml description**

将 `android/app/src/main/res/values/strings.xml` 改为：

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="preparation_widget_description">备赛倒计时、进度与阶段 · 四档尺寸自适应 · 多计划轮换</string>
</resources>
```

- [ ] **Step 13: 跑测试确认通过**

Run: `"D:/Program Files/Flutter/flutter/bin/flutter.bat" test test/android_manifest_test.dart`
Expected: PASS（含新增 3 个 test）

- [ ] **Step 14: Commit**

```bash
git add android/app/src/main/res/layout android/app/src/main/res/drawable android/app/src/main/res/xml android/app/src/main/res/values/strings.xml test/android_manifest_test.dart
git commit -m "feat(widget): 四档 layout + 渐变进度 + 阶段轴 drawable 资源"
```

---

### Task 6: PreparationWidgetProvider 四档尺寸分派 + ACTION_ROTATE + 阶段轴着色

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/scho_navi/PreparationWidgetProvider.kt`

**Interfaces:**
- Consumes: `ReminderPlan.phases`（Task 4）；四档 layout（Task 5）。
- Produces: 按 `OPTION_APPWIDGET_MIN_WIDTH/MIN_HEIGHT` 选 layout；`ACTION_ROTATE` 触发 `rotate=true`；`ACTION_REFRESH` 保持 `rotate=false`；阶段轴 5 段按 status 着色。

- [ ] **Step 1: 加 ACTION_ROTATE 常量与 onReceive 分流**

在 [PreparationWidgetProvider.kt](android/app/src/main/kotlin/com/example/scho_navi/PreparationWidgetProvider.kt) `companion object` 中加：

```kotlin
        const val ACTION_ROTATE = "com.example.scho_navi.action.ROTATE_PREPARATION_WIDGET"
```

修改 `onReceive`：

```kotlin
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_REFRESH -> {
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(ComponentName(context, PreparationWidgetProvider::class.java))
                ids.forEach { render(context, manager, it, rotate = false) }
            }
            ACTION_ROTATE -> {
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(ComponentName(context, PreparationWidgetProvider::class.java))
                ids.forEach { render(context, manager, it, rotate = true) }
            }
            else -> super.onReceive(context, intent)
        }
    }
```

- [ ] **Step 2: 尺寸分派函数**

在 `render` 方法上方加：

```kotlin
    private fun layoutFor(options: Bundle): Int {
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        return when {
            minWidth < 180 || minHeight < 110 -> R.layout.preparation_widget_micro
            minWidth < 250 -> R.layout.preparation_widget_small
            minHeight < 180 -> R.layout.preparation_widget_wide
            else -> R.layout.preparation_widget_hero
        }
    }
```

- [ ] **Step 3: render 选 layout**

将 `render` 内的 `val views = RemoteViews(...)` 改为：

```kotlin
        val views = RemoteViews(context.packageName, layoutFor(options))
```

删除原 `val expanded = ...` 行。

- [ ] **Step 4: 阶段轴着色**

在 `render` 方法内、`manager.updateAppWidget(appWidgetId, views)` 之前，加阶段轴着色（仅 Hero layout 含 phase id，其他 layout `setViewVisibility` 对不存在的 id 无害）：

```kotlin
        bindPhaseRow(views, plan)
```

并在类内加 helper：

```kotlin
    private fun bindPhaseRow(context: Context, views: RemoteViews, plan: ReminderPlan) {
        val phases = plan.phases
        val phaseViewIds = intArrayOf(
            R.id.widget_phase_0, R.id.widget_phase_1, R.id.widget_phase_2,
            R.id.widget_phase_3, R.id.widget_phase_4,
        )
        val labelViewIds = intArrayOf(
            R.id.widget_phase_label_0, R.id.widget_phase_label_1, R.id.widget_phase_label_2,
            R.id.widget_phase_label_3, R.id.widget_phase_label_4,
        )
        for (i in phaseViewIds.indices) {
            if (i < phases.size) {
                val phase = phases[i]
                views.setViewVisibility(phaseViewIds[i], View.VISIBLE)
                views.setViewVisibility(labelViewIds[i], View.VISIBLE)
                val drawable = when (phase.status) {
                    "completed" -> R.drawable.preparation_widget_phase_done
                    "active" -> R.drawable.preparation_widget_phase_active
                    else -> R.drawable.preparation_widget_phase_upcoming
                }
                views.setInt(phaseViewIds[i], "setBackgroundResource", drawable)
                views.setTextViewText(labelViewIds[i], phase.title)
                views.setTextColor(
                    labelViewIds[i],
                    if (phase.status == "active") {
                        androidx.core.content.ContextCompat.getColor(context, R.color.widget_primary)
                    } else {
                        androidx.core.content.ContextCompat.getColor(context, R.color.widget_text_secondary)
                    },
                )
            } else {
                views.setViewVisibility(phaseViewIds[i], View.INVISIBLE)
                views.setViewVisibility(labelViewIds[i], View.INVISIBLE)
            }
        }
    }
```

调用处（`render` 内、`manager.updateAppWidget` 之前）：

```kotlin
        bindPhaseRow(context, views, plan)
```

注：`widget_phase`（单行阶段文本，Small/Wide 用）的 `setTextViewText` 保持不动；阶段轴 5 段仅 Hero layout 有对应 id，其他 layout 调用 `setViewVisibility` 对不存在的 id 是无害空操作。

- [ ] **Step 5: 编译验证**

Run: `cd android && ./gradlew :app:compileDebugKotlin 2>&1 | tail -20`（或 `flutter build apk --debug` 间接编译）
Expected: BUILD SUCCESSFUL

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/example/scho_navi/PreparationWidgetProvider.kt
git commit -m "feat(widget): 四档尺寸分派 + ACTION_ROTATE + 阶段轴着色"
```

---

### Task 7: WidgetRotationScheduler + WidgetRotationReceiver + manifest 注册

**Files:**
- Create: `android/app/src/main/kotlin/com/example/scho_navi/WidgetRotationScheduler.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/kotlin/com/example/scho_navi/MainActivity.kt`
- Test: `test/android_manifest_test.dart`

**Interfaces:**
- Consumes: `PreparationWidgetProvider.ACTION_ROTATE`（Task 6）；`ReminderStorage.loadSnapshot`。
- Produces: `WidgetRotationScheduler.start(context)` / `stop(context)`；`WidgetRotationReceiver` 注册在 manifest。

- [ ] **Step 1: 写 manifest 注册测试**

在 [test/android_manifest_test.dart](test/android_manifest_test.dart) `main` 闭包末尾新增：

```dart
  test('main Android manifest registers widget rotation receiver', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:name=".WidgetRotationReceiver"'));
    expect(
      manifest,
      contains('com.example.scho_navi.action.ROTATE_PREPARATION_WIDGET'),
    );
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"D:/Program Files/Flutter/flutter/bin/flutter.bat" test test/android_manifest_test.dart`
Expected: FAIL，`android:name=".WidgetRotationReceiver"` not found

- [ ] **Step 3: 新建 WidgetRotationScheduler.kt**

创建 `android/app/src/main/kotlin/com/example/scho_navi/WidgetRotationScheduler.kt`：

```kotlin
package com.example.scho_navi

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent

object WidgetRotationScheduler {
    private const val REQUEST_CODE = 4107
    private const val INTERVAL_MS = 30_000L

    fun apply(context: Context) {
        val snapshot = ReminderStorage.loadSnapshot(context)
        val shouldRun = snapshot.plans.size > 1
        if (shouldRun) start(context) else stop(context)
    }

    fun start(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val pendingIntent = pendingIntent(context)
        alarmManager.cancel(pendingIntent)
        alarmManager.setRepeating(
            AlarmManager.RTC,
            System.currentTimeMillis() + INTERVAL_MS,
            INTERVAL_MS,
            pendingIntent,
        )
    }

    fun stop(context: Context) {
        context.getSystemService(AlarmManager::class.java)
            .cancel(pendingIntent(context))
    }

    private fun pendingIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        REQUEST_CODE,
        Intent(context, WidgetRotationReceiver::class.java).apply {
            action = PreparationWidgetProvider.ACTION_ROTATE
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}

class WidgetRotationReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != PreparationWidgetProvider.ACTION_ROTATE) return
        // 转发给 PreparationWidgetProvider，复用其 onReceive(ACTION_ROTATE) 做 rotate=true 渲染。
        context.sendBroadcast(
            Intent(context, PreparationWidgetProvider::class.java).apply {
                action = PreparationWidgetProvider.ACTION_ROTATE
            },
        )
    }
}
```

- [ ] **Step 4: manifest 注册 receiver**

在 [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) `<receiver android:name=".ReminderRescheduleReceiver">...</receiver>` 之后加：

```xml
        <receiver
            android:name=".WidgetRotationReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="com.example.scho_navi.action.ROTATE_PREPARATION_WIDGET"/>
            </intent-filter>
        </receiver>
```

- [ ] **Step 5: MainActivity 接入 start/stop**

在 [MainActivity.kt](android/app/src/main/kotlin/com/example/scho_navi/MainActivity.kt) 的 `handleReminderCall` 的 `"syncSnapshot"` 分支，`PreparationWidgetProvider.refreshAll(this)` 之后加：

```kotlin
                    PreparationWidgetProvider.refreshAll(this)
                    WidgetRotationScheduler.apply(this)
```

在 `onCreate` 的 `super.onCreate(savedInstanceState)` 之后、`splashScreen` 之前加（若 snapshot 非空则启动轮换）：

```kotlin
        WidgetRotationScheduler.apply(this)
```

- [ ] **Step 6: 跑测试确认通过**

Run: `"D:/Program Files/Flutter/flutter/bin/flutter.bat" test test/android_manifest_test.dart`
Expected: PASS

- [ ] **Step 7: 编译验证**

Run: `cd android && ./gradlew :app:compileDebugKotlin 2>&1 | tail -20`
Expected: BUILD SUCCESSFUL

- [ ] **Step 8: Commit**

```bash
git add android/app/src/main/kotlin/com/example/scho_navi/WidgetRotationScheduler.kt android/app/src/main/kotlin/com/example/scho_navi/MainActivity.kt android/app/src/main/AndroidManifest.xml test/android_manifest_test.dart
git commit -m "feat(widget): AlarmManager 30s 轮换 + WidgetRotationReceiver 注册"
```

---

### Task 8: 全量验证 + format

**Files:**
- 全仓库

- [ ] **Step 1: dart format 检查**

Run: `"D:/Program Files/Flutter/flutter/bin/flutter.bat" format --set-exit-if-changed lib test`
Expected: 无变更（若有变更先 `dart format lib test` 再 commit）

- [ ] **Step 2: flutter analyze**

Run: `"D:/Program Files/Flutter/flutter/bin/flutter.bat" analyze`
Expected: 无新增 error/warning

- [ ] **Step 3: 相关 flutter test**

Run: `"D:/Program Files/Flutter/flutter/bin/flutter.bat" test test/data/local/preparation_reminder_store_test.dart test/domain/services/preparation_reminder_builder_test.dart test/android_manifest_test.dart`
Expected: 全 PASS

- [ ] **Step 4: Commit format 修复（若有）**

```bash
git add lib test
git commit -m "chore(format): apply dart format" 2>/dev/null || echo "no format changes"
```

- [ ] **Step 5: 人工验证说明**

实机验证需设备/模拟器（添加小组件、拖拽四档、切明暗、等 30s 轮换）。若本地无法实机，在交付说明里注明"未做实机验证，仅 Dart 测试 + 资源/manifest 断言 + Kotlin 编译通过"。

---

## Self-Review 记录

（实现时由执行者填写：spec 覆盖、占位符扫描、类型一致性检查结果。）
