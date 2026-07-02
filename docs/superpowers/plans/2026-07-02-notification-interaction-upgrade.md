# 通知交互升级 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把单条每日提醒升级为完整 Android 通知系统使用——3 通道、真实分组、每日摘要、动作按钮后台闭环（含 headless engine）、独立截止提醒、重启恢复。

**Architecture:** Flutter 导出事实（pendingTasks / deadlineAlerts，不按 today 过滤），原生在触发当天投影 digest；通知动作走独立反向通道 `notification_actions`，App 未运行时启动 `notificationActionMain` headless engine；闹钟用 data URI 标识 + 持久化 registry diff 处理孤儿/过期。

**Tech Stack:** Flutter/Dart, flutter_riverpod, MethodChannel, Kotlin (AlarmManager, NotificationManager, BroadcastReceiver, headless FlutterEngine), SharedPreferences, drift/shared_preferences。

## Global Constraints

- 不引入新状态管理/路由/持久化/后台任务库。
- 不申请 `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`；用 `setAndAllowWhileIdle()`，文案统一「目标时刻」「约 1 小时后」，不写「准时」。
- 动作必须携带 `planId + taskId`，禁止仅凭 planId 重新猜测任务；禁止「今日无任务时自动完成未来任务」。
- snapshot `deadlineAlerts` 不按 today 过滤；原生调度时才丢弃 `triggerAt <= now`。
- 保留 mock/local 路径可用；不破坏 v1/v2 snapshot 兼容。
- 文案保持中文产品风格。
- Default to no comments；仅命名不能表达意图时加短注释。
- 每个 Task 结束前跑 `flutter analyze` + 相关 `flutter test`，全绿才 commit。

## File Structure

### Flutter/Dart

| 文件 | 责任 | 状态 |
|---|---|---|
| `lib/domain/entities/preparation_reminder.dart` | `PreparationReminderTask`、`DeadlineAlert`、snapshot v3 | 改 |
| `lib/domain/services/preparation_reminder_builder.dart` | 构建 pendingTasks + deadlineAlerts 事实 | 改 |
| `lib/features/preparation/services/complete_notification_task_use_case.dart` | 精确 planId/taskId 幂等完成 + 返回 snapshot | 新 |
| `lib/features/preparation/providers/preparation_reminder_providers.dart` | UI engine 注册 `notification_actions` Dart handler | 改 |
| `lib/main.dart` | `@pragma('vm:entry-point') notificationActionMain` | 改 |
| `test/domain/services/preparation_reminder_builder_test.dart` | pendingTasks / deadlineAlerts 用例 | 改 |
| `test/features/preparation/services/complete_notification_task_use_case_test.dart` | 完成用例 | 新 |
| `test/core/platform/notification_action_channel_test.dart` | 反向通道 handler 契约 | 新 |
| `test/data/local/preparation_reminder_store_test.dart` | v3 兼容 | 改 |

### Android/Kotlin

| 文件 | 责任 | 状态 |
|---|---|---|
| `android/app/src/main/kotlin/com/example/scho_navi/ReminderStorage.kt` | v3 解析 + `ReminderAlarmRegistry` | 改 |
| `android/app/src/main/kotlin/com/example/scho_navi/ReminderScheduler.kt` | 拆 `DailyReminderReceiver`、daily data URI | 改 |
| `android/app/src/main/kotlin/com/example/scho_navi/DeadlineAlarmScheduler.kt` | 按日批处理 + registry diff | 新 |
| `android/app/src/main/kotlin/com/example/scho_navi/ReminderNotificationFactory.kt` | channel/group/通知构建 + tag | 新 |
| `android/app/src/main/kotlin/com/example/scho_navi/ReminderActionReceiver.kt` | COMPLETE/SNOOZE + `SnoozedTaskReceiver` | 新 |
| `android/app/src/main/kotlin/com/example/scho_navi/NotificationActionCoordinator.kt` | UI/headless engine + single-flight + 超时 | 新 |
| `android/app/src/main/kotlin/com/example/scho_navi/MainActivity.kt` | 注册 `notification_actions`、创建 channel、reconcile | 改 |
| `android/app/src/main/AndroidManifest.xml` | 替换/注册新 Receiver | 改 |

---

## Task 1: Snapshot schema v3 — PreparationReminderTask & DeadlineAlert entities

**Files:**
- Modify: `lib/domain/entities/preparation_reminder.dart`
- Test: `test/domain/services/preparation_reminder_builder_test.dart`（仅实体序列化部分，builder 用例在 Task 2）

**Interfaces:**
- Produces:
  - `class PreparationReminderTask { String taskId; String title; String dueIsoDay; int sortOrder; }` + `toJson`/`fromJson`
  - `class DeadlineAlert { String planId; String competitionName; String alertIsoDay; int daysBefore; String deadlineIsoDay; }` + `toJson`/`fromJson`
  - `PreparationReminderPlanSummary` 新增 `List<PreparationReminderTask> pendingTasks`（默认 `const []`）
  - `PreparationReminderSnapshot` 新增 `List<DeadlineAlert> deadlineAlerts`（默认 `const []`）
  - `schemaVersion = 3`

- [ ] **Step 1: Write failing tests for entity serialization**

追加到 `test/domain/services/preparation_reminder_builder_test.dart` 末尾 `main()` 内：

```dart
  test('PreparationReminderTask round-trips JSON', () {
    final task = PreparationReminderTask(
      taskId: 't1',
      title: '刷题',
      dueIsoDay: '2026-07-02',
      sortOrder: 0,
    );
    final json = task.toJson();
    final back = PreparationReminderTask.fromJson(json);
    expect(back, task);
    expect(json, {
      'taskId': 't1',
      'title': '刷题',
      'dueIsoDay': '2026-07-02',
      'sortOrder': 0,
    });
  });

  test('DeadlineAlert round-trips JSON', () {
    final alert = DeadlineAlert(
      planId: 'p1',
      competitionName: '竞赛 X',
      alertIsoDay: '2026-07-05',
      daysBefore: 7,
      deadlineIsoDay: '2026-07-12',
    );
    final json = alert.toJson();
    final back = DeadlineAlert.fromJson(json);
    expect(back, alert);
    expect(json, {
      'planId': 'p1',
      'competitionName': '竞赛 X',
      'alertIsoDay': '2026-07-05',
      'daysBefore': 7,
      'deadlineIsoDay': '2026-07-12',
    });
  });

  test('Snapshot v3 serializes deadlineAlerts and pendingTasks', () {
    final snapshot = PreparationReminderSnapshot(
      generatedAt: DateTime(2026, 7, 2),
      currentStreak: 1,
      preparedToday: true,
      lastActivityDay: '2026-07-01',
      plans: const [],
      deadlineAlerts: const [
        DeadlineAlert(
          planId: 'p1',
          competitionName: '竞赛 X',
          alertIsoDay: '2026-07-05',
          daysBefore: 7,
          deadlineIsoDay: '2026-07-12',
        ),
      ],
    );
    final json = snapshot.toJson();
    expect(json['schemaVersion'], 3);
    expect((json['deadlineAlerts'] as List).length, 1);
  });
```

在文件顶部确认 import 已含 `preparation_reminder.dart`（已含）。

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/domain/services/preparation_reminder_builder_test.dart`
Expected: 编译失败——`PreparationReminderTask`/`DeadlineAlert` 未定义、`deadlineAlerts` 参数不存在。

- [ ] **Step 3: Implement entities**

在 `lib/domain/entities/preparation_reminder.dart`：

在 `ReminderPhaseStatus` enum 定义之后（约 line 36 附近）新增：

```dart
class PreparationReminderTask {
  const PreparationReminderTask({
    required this.taskId,
    required this.title,
    required this.dueIsoDay,
    required this.sortOrder,
  });

  final String taskId;
  final String title;
  final String dueIsoDay;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'title': title,
    'dueIsoDay': dueIsoDay,
    'sortOrder': sortOrder,
  };

  factory PreparationReminderTask.fromJson(Map<String, dynamic> json) =>
      PreparationReminderTask(
        taskId: json['taskId'] as String,
        title: json['title'] as String,
        dueIsoDay: json['dueIsoDay'] as String,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PreparationReminderTask &&
          taskId == other.taskId &&
          title == other.title &&
          dueIsoDay == other.dueIsoDay &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode => Object.hash(taskId, title, dueIsoDay, sortOrder);
}
```

在 `PreparationReminderPlanSummary` 类中：
- 新增字段 `final List<PreparationReminderTask> pendingTasks;`，构造函数加 `this.pendingTasks = const []`
- `toJson` 增加 `if (pendingTasks.isNotEmpty) 'pendingTasks': pendingTasks.map((t) => t.toJson()).toList(growable: false),`
- `fromJson` 末尾解析：`pendingTasks: ((json['pendingTasks'] as List?) ?? const []).map((t) => PreparationReminderTask.fromJson(t as Map<String, dynamic>)).toList(growable: false),`

在文件末尾（`_isoDay` 函数之前）新增 `DeadlineAlert`：

```dart
class DeadlineAlert {
  const DeadlineAlert({
    required this.planId,
    required this.competitionName,
    required this.alertIsoDay,
    required this.daysBefore,
    required this.deadlineIsoDay,
  });

  final String planId;
  final String competitionName;
  final String alertIsoDay;
  final int daysBefore;
  final String deadlineIsoDay;

  Map<String, dynamic> toJson() => {
    'planId': planId,
    'competitionName': competitionName,
    'alertIsoDay': alertIsoDay,
    'daysBefore': daysBefore,
    'deadlineIsoDay': deadlineIsoDay,
  };

  factory DeadlineAlert.fromJson(Map<String, dynamic> json) => DeadlineAlert(
    planId: json['planId'] as String,
    competitionName: json['competitionName'] as String,
    alertIsoDay: json['alertIsoDay'] as String,
    daysBefore: (json['daysBefore'] as num?)?.toInt() ?? 0,
    deadlineIsoDay: json['deadlineIsoDay'] as String,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeadlineAlert &&
          planId == other.planId &&
          alertIsoDay == other.alertIsoDay &&
          daysBefore == other.daysBefore;

  @override
  int get hashCode => Object.hash(planId, alertIsoDay, daysBefore);
}
```

在 `PreparationReminderSnapshot`：
- `schemaVersion` 改为 `3`
- 新增 `final List<DeadlineAlert> deadlineAlerts;`，构造函数 `this.deadlineAlerts = const []`
- `toJson` 增加 `'deadlineAlerts': deadlineAlerts.map((a) => a.toJson()).toList(growable: false),`

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/domain/services/preparation_reminder_builder_test.dart`
Expected: 3 个新测试 PASS，旧测试可能因 builder 未输出 pendingTasks/deadlineAlerts 而需要 Task 2 补齐——若旧测试断言了 toJson 完整结构会失败，先在 Task 2 修复。

- [ ] **Step 5: analyze + commit**

```bash
flutter analyze lib/domain/entities/preparation_reminder.dart
git add lib/domain/entities/preparation_reminder.dart test/domain/services/preparation_reminder_builder_test.dart
git commit -m "feat(reminder): snapshot schema v3 — PreparationReminderTask + DeadlineAlert entities"
```

---

## Task 2: Builder — pendingTasks + deadlineAlerts facts

**Files:**
- Modify: `lib/domain/services/preparation_reminder_builder.dart`
- Test: `test/domain/services/preparation_reminder_builder_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `PreparationReminderTask`、`DeadlineAlert`、`PreparationPlan`（含 `targetDate`、`phases[].tasks[]`）
- Produces: `PreparationReminderBuilder.build()` 返回的 snapshot 含
  - 每个 active plan summary 的 `pendingTasks`（仅未完成，按 dueDate → kind rank → 原顺序，`sortOrder` 为该排序后的稳定索引）
  - snapshot 的 `deadlineAlerts`：每个 active plan 生成 3 条（d-7/d-3/d），**不按 today 过滤**，按 `alertIsoDay, deadlineIsoDay, planId, daysBefore` 升序

- [ ] **Step 1: Write failing tests**

追加到 `test/domain/services/preparation_reminder_builder_test.dart`：

```dart
  test('pendingTasks only includes incomplete tasks and sorts by due/kind/order', () {
    final due = DateTime(2026, 7, 2);
    final snapshot = builder.build(
      plans: [
        plan(
          id: 'p1',
          targetDate: DateTime(2026, 8, 1),
          tasks: [
            PreparationTask(
              id: 'done',
              title: '已完成',
              kind: PreparationTaskKind.required,
              estimatedHours: 2,
              dueDate: due,
              completedAt: DateTime(2026, 7, 1),
            ),
            PreparationTask(
              id: 'opt',
              title: '可选',
              kind: PreparationTaskKind.optional,
              estimatedHours: 1,
              dueDate: due,
            ),
            PreparationTask(
              id: 'req',
              title: '必做',
              kind: PreparationTaskKind.required,
              estimatedHours: 3,
              dueDate: due,
            ),
          ],
        ),
      ],
      activityDays: const {},
      now: now,
    );
    final tasks = snapshot.plans.first.pendingTasks;
    expect(tasks.map((t) => t.taskId), ['req', 'opt']);
    expect(tasks.first.sortOrder, 0);
    expect(tasks.last.sortOrder, 1);
    expect(snapshot.plans.first.nextTaskTitle, '必做');
  });

  test('deadlineAlerts generate 3 facts per active plan without today filtering', () {
    final snapshot = builder.build(
      plans: [
        plan(id: 'p1', targetDate: DateTime(2026, 8, 15)),
      ],
      activityDays: const {},
      now: DateTime(2026, 6, 30),
    );
    final alerts = snapshot.deadlineAlerts;
    expect(alerts.map((a) => a.alertIsoDay).toList(), [
      '2026-08-08', // d-7
      '2026-08-12', // d-3
      '2026-08-15', // d
    ]);
    expect(alerts.first.daysBefore, 7);
    expect(alerts.last.daysBefore, 0);
    expect(alerts.every((a) => a.planId == 'p1'), isTrue);
  });

  test('deadlineAlerts skip archived plans', () {
    final snapshot = builder.build(
      plans: [
        plan(id: 'p1', targetDate: DateTime(2026, 8, 15)),
        plan(
          id: 'arch',
          targetDate: DateTime(2026, 8, 15),
          status: PreparationPlanStatus.archived,
        ),
      ],
      activityDays: const {},
      now: DateTime(2026, 6, 30),
    );
    expect(snapshot.deadlineAlerts.every((a) => a.planId == 'p1'), isTrue);
    expect(snapshot.deadlineAlerts.length, 3);
  });

  test('deadlineAlerts sort by alertIsoDay then planId', () {
    final snapshot = builder.build(
      plans: [
        plan(id: 'b', targetDate: DateTime(2026, 8, 15)),
        plan(id: 'a', targetDate: DateTime(2026, 8, 15)),
      ],
      activityDays: const {},
      now: DateTime(2026, 6, 30),
    );
    // 同 alertIsoDay 下按 planId
    final d7 = snapshot.deadlineAlerts.where((a) => a.daysBefore == 7).toList();
    expect(d7.map((a) => a.planId), ['a', 'b']);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/domain/services/preparation_reminder_builder_test.dart`
Expected: FAIL — `pendingTasks`/`deadlineAlerts` 为空（builder 未实现）。

- [ ] **Step 3: Implement builder**

在 `lib/domain/services/preparation_reminder_builder.dart`：

修改 `_summary` 方法，在计算 `incomplete` 后构建 `pendingTasks`：

```dart
    final pendingTasks = [
      for (final entry in incomplete)
        PreparationReminderTask(
          taskId: entry.task.id,
          title: entry.task.title,
          dueIsoDay: _isoDay(entry.task.dueDate),
          sortOrder: 0, // 占位，下面赋真实索引
        ),
    ];
    final pendingTasksWithOrder = [
      for (var i = 0; i < pendingTasks.length; i++)
        pendingTasks[i].copyWith(sortOrder: i),
    ];
```

`copyWith` 需在 `PreparationReminderTask` 加（Task 1 已加 `copyWith`？若未加，在 Task 1 实现时补：见 Task 1 Step 3 末尾补充 `copyWith`）。补在 Task 1 实体类内：

```dart
  PreparationReminderTask copyWith({
    String? taskId,
    String? title,
    String? dueIsoDay,
    int? sortOrder,
  }) => PreparationReminderTask(
    taskId: taskId ?? this.taskId,
    title: title ?? this.title,
    dueIsoDay: dueIsoDay ?? this.dueIsoDay,
    sortOrder: sortOrder ?? this.sortOrder,
  );
```

`_summary` 返回的 `PreparationReminderPlanSummary` 构造加 `pendingTasks: pendingTasksWithOrder`。

在 `build` 方法中，return snapshot 前计算 `deadlineAlerts`：

```dart
    final deadlineAlerts = <DeadlineAlert>[];
    for (final plan in activePlans) {
      final deadline = _isoDay(plan.targetDate);
      final target = plan.targetDate;
      for (final days in const [7, 3, 0]) {
        final alertDay = days == 0 ? target : target.subtract(Duration(days: days));
        deadlineAlerts.add(DeadlineAlert(
          planId: plan.id,
          competitionName: plan.competition.name,
          alertIsoDay: _isoDay(alertDay),
          daysBefore: days,
          deadlineIsoDay: deadline,
        ));
      }
    }
    deadlineAlerts.sort((a, b) {
      final byAlert = a.alertIsoDay.compareTo(b.alertIsoDay);
      if (byAlert != 0) return byAlert;
      final byDeadline = a.deadlineIsoDay.compareTo(b.deadlineIsoDay);
      if (byDeadline != 0) return byDeadline;
      final byPlan = a.planId.compareTo(b.planId);
      if (byPlan != 0) return byPlan;
      return a.daysBefore.compareTo(b.daysBefore);
    });
```

`PreparationReminderSnapshot` 构造调用加 `deadlineAlerts: deadlineAlerts`。

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/domain/services/preparation_reminder_builder_test.dart`
Expected: 全部 PASS。

- [ ] **Step 5: analyze + commit**

```bash
flutter analyze lib/domain/services/preparation_reminder_builder.dart
git add lib/domain/services/preparation_reminder_builder.dart lib/domain/entities/preparation_reminder.dart test/domain/services/preparation_reminder_builder_test.dart
git commit -m "feat(reminder): builder 输出 pendingTasks + deadlineAlerts 事实"
```

---

## Task 3: CompleteNotificationTaskUseCase

**Files:**
- Create: `lib/features/preparation/services/complete_notification_task_use_case.dart`
- Test: `test/features/preparation/services/complete_notification_task_use_case_test.dart`

**Interfaces:**
- Consumes: `PreparationPlanRepository`（`findById`、`save`），`PreparationReminderBuilder`，`Set<String> activityDays`，`DateTime Function() now`
- Produces:
  ```dart
  enum CompleteTaskResult { completed, alreadyCompleted, notFound, conflict, persistenceFailed }
  class CompleteTaskOutcome {
    final CompleteTaskResult result;
    final PreparationReminderSnapshot? snapshot;
  }
  Future<CompleteTaskOutcome> call({required String planId, required String taskId});
  ```

- [ ] **Step 1: Write failing tests**

`test/features/preparation/services/complete_notification_task_use_case_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/domain/repositories/preparation_plan_repository.dart';
import 'package:scho_navi/domain/services/preparation_reminder_builder.dart';
import 'package:scho_navi/features/preparation/services/complete_notification_task_use_case.dart';

class _FakeRepo implements PreparationPlanRepository {
  _FakeRepo(this._plans);
  List<PreparationPlan> _plans;
  int saveCalls = 0;
  int? forceConflictOnRevision;

  @override
  List<PreparationPlan> list() => _plans;

  @override
  PreparationPlan? findById(String id) {
    for (final p in _plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<PreparationPlan> save(PreparationPlan plan) async {
    saveCalls++;
    if (forceConflictOnRevision != null && plan.revision == forceConflictOnRevision) {
      throw const ConflictException();
    }
    final updated = plan.copyWith(
      revision: plan.revision + 1,
      updatedAt: DateTime(2026, 7, 2),
    );
    _plans = [updated, ..._plans.where((p) => p.id != plan.id)];
    return updated;
  }

  @override
  PreparationPlan? activeForCompetition(String competitionId) => null;
  @override
  Stream<List<PreparationPlan>> watch() => const Stream.empty();
  @override
  Future<void> archive(String id) async {}
  @override
  Future<void> delete(String id) async {}
}

PreparationTask _task({
  required String id,
  bool completed = false,
  PreparationTaskKind kind = PreparationTaskKind.required,
}) =>
    PreparationTask(
      id: id,
      title: 't$id',
      kind: kind,
      estimatedHours: 1,
      dueDate: DateTime(2026, 7, 2),
      completedAt: completed ? DateTime(2026, 7, 1) : null,
    );

PreparationPlan _plan({
  required String id,
  required List<PreparationTask> tasks,
  int revision = 0,
}) =>
    PreparationPlan(
      id: id,
      competition: CompetitionSnapshot(
        id: 'c$id',
        name: '竞赛 $id',
        category: '计算机类',
        rulesSummary: const CompetitionRulesSummary(
          signupTime: '', contestTime: '', teamSize: '', format: '', organizer: '',
        ),
      ),
      targetDate: DateTime(2026, 8, 15),
      weeklyCommitment: WeeklyCommitment.hours6to10,
      experienceLevel: ExperienceLevel.beginner,
      status: PreparationPlanStatus.active,
      revision: revision,
      phases: [
        PreparationPhase(
          key: 'p',
          title: '阶段',
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 7, 31),
          tasks: tasks,
        ),
      ],
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

void main() {
  const builder = PreparationReminderBuilder();
  final now = DateTime(2026, 7, 2, 12);

  test('completes exact taskId and returns v3 snapshot', () async {
    final repo = _FakeRepo([_plan(id: 'p1', tasks: [_task(id: 't1'), _task(id: 't2')])]);
    final useCase = CompleteNotificationTaskUseCase(
      repository: repo,
      builder: builder,
      activityDays: const {},
      now: () => now,
    );
    final outcome = await useCase.call(planId: 'p1', taskId: 't1');
    expect(outcome.result, CompleteTaskResult.completed);
    expect(outcome.snapshot, isNotNull);
    expect(outcome.snapshot!.schemaVersion, 3);
    expect(repo.saveCalls, 1);
    final saved = repo.findById('p1')!;
    expect(saved.phases.first.tasks.firstWhere((t) => t.id == 't1').completed, isTrue);
    expect(saved.phases.first.tasks.firstWhere((t) => t.id == 't2').completed, isFalse);
  });

  test('already-completed task returns idempotent success', () async {
    final repo = _FakeRepo([_plan(id: 'p1', tasks: [_task(id: 't1', completed: true)])]);
    final useCase = CompleteNotificationTaskUseCase(
      repository: repo, builder: builder, activityDays: const {}, now: () => now,
    );
    final outcome = await useCase.call(planId: 'p1', taskId: 't1');
    expect(outcome.result, CompleteTaskResult.alreadyCompleted);
    expect(repo.saveCalls, 0);
    expect(outcome.snapshot, isNotNull);
  });

  test('missing plan returns notFound without saving', () async {
    final repo = _FakeRepo([]);
    final useCase = CompleteNotificationTaskUseCase(
      repository: repo, builder: builder, activityDays: const {}, now: () => now,
    );
    final outcome = await useCase.call(planId: 'missing', taskId: 't1');
    expect(outcome.result, CompleteTaskResult.notFound);
    expect(repo.saveCalls, 0);
    expect(outcome.snapshot, isNull);
  });

  test('CAS conflict retries once then returns conflict', () async {
    final repo = _FakeRepo([_plan(id: 'p1', revision: 0, tasks: [_task(id: 't1')])]);
    repo.forceConflictOnRevision = 0; // 第一次 save 抛 ConflictException
    final useCase = CompleteNotificationTaskUseCase(
      repository: repo, builder: builder, activityDays: const {}, now: () => now,
    );
    final outcome = await useCase.call(planId: 'p1', taskId: 't1');
    expect(outcome.result, CompleteTaskResult.conflict);
    // retry 用最新 plan（仍 revision 0，仍冲突）→ conflict
  });
}
```

需 `import 'package:scho_navi/core/error/app_exception.dart';` 以引用 `ConflictException`。

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/preparation/services/complete_notification_task_use_case_test.dart`
Expected: FAIL — 文件不存在，编译错误。

- [ ] **Step 3: Implement use case**

`lib/features/preparation/services/complete_notification_task_use_case.dart`：

```dart
import '../../../core/error/app_exception.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../domain/entities/preparation_reminder.dart';
import '../../../domain/repositories/preparation_plan_repository.dart';
import '../../../domain/services/preparation_reminder_builder.dart';

enum CompleteTaskResult { completed, alreadyCompleted, notFound, conflict, persistenceFailed }

class CompleteTaskOutcome {
  const CompleteTaskOutcome(this.result, this.snapshot);
  final CompleteTaskResult result;
  final PreparationReminderSnapshot? snapshot;
}

class CompleteNotificationTaskUseCase {
  CompleteNotificationTaskUseCase({
    required PreparationPlanRepository repository,
    required PreparationReminderBuilder builder,
    required Set<String> activityDays,
    required DateTime Function() now,
  })  : _repository = repository,
        _builder = builder,
        _activityDays = activityDays,
        _now = now;

  final PreparationPlanRepository _repository;
  final PreparationReminderBuilder _builder;
  final Set<String> _activityDays;
  final DateTime Function() _now;

  Future<CompleteTaskOutcome> call({
    required String planId,
    required String taskId,
  }) async {
    final plan = _repository.findById(planId);
    if (plan == null) return const CompleteTaskOutcome(CompleteTaskResult.notFound, null);

    final task = _findTask(plan, taskId);
    if (task == null) return const CompleteTaskOutcome(CompleteTaskResult.notFound, null);
    if (task.completed) {
      return CompleteTaskOutcome(CompleteTaskResult.alreadyCompleted, _buildSnapshot());
    }

    final updatedPlan = _replaceTask(plan, task.id, task.copyWith(completedAt: _now()));
    try {
      await _repository.save(updatedPlan);
    } on ConflictException {
      // CAS 冲突：重新读取一次最新版本重试
      final fresh = _repository.findById(planId);
      if (fresh == null) return const CompleteTaskOutcome(CompleteTaskResult.notFound, null);
      final freshTask = _findTask(fresh, taskId);
      if (freshTask == null) return const CompleteTaskOutcome(CompleteTaskResult.notFound, null);
      if (freshTask.completed) {
        return CompleteTaskOutcome(CompleteTaskResult.alreadyCompleted, _buildSnapshot());
      }
      final retryPlan = _replaceTask(fresh, freshTask.id, freshTask.copyWith(completedAt: _now()));
      try {
        await _repository.save(retryPlan);
      } on ConflictException {
        return const CompleteTaskOutcome(CompleteTaskResult.conflict, null);
      } catch (_) {
        return const CompleteTaskOutcome(CompleteTaskResult.persistenceFailed, null);
      }
    } catch (_) {
      return const CompleteTaskOutcome(CompleteTaskResult.persistenceFailed, null);
    }

    return CompleteTaskOutcome(CompleteTaskResult.completed, _buildSnapshot());
  }

  PreparationTask? _findTask(PreparationPlan plan, String taskId) {
    for (final phase in plan.phases) {
      for (final task in phase.tasks) {
        if (task.id == taskId) return task;
      }
    }
    return null;
  }

  PreparationPlan _replaceTask(PreparationPlan plan, String taskId, PreparationTask updated) {
    return plan.copyWith(
      phases: plan.phases
          .map((phase) => phase.copyWith(
                tasks: phase.tasks
                    .map((t) => t.id == taskId ? updated : t)
                    .toList(growable: false),
              ))
          .toList(growable: false),
    );
  }

  PreparationReminderSnapshot _buildSnapshot() {
    return _builder.build(
      plans: _repository.list(),
      activityDays: _activityDays,
      now: _now(),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/preparation/services/complete_notification_task_use_case_test.dart`
Expected: 4 个测试 PASS。

- [ ] **Step 5: analyze + commit**

```bash
flutter analyze lib/features/preparation/services/complete_notification_task_use_case.dart
git add lib/features/preparation/services/complete_notification_task_use_case.dart test/features/preparation/services/complete_notification_task_use_case_test.dart
git commit -m "feat(preparation): CompleteNotificationTaskUseCase 幂等完成任务"
```

---

## Task 4: notification_actions 反向通道 — Dart handler + provider 注册

**Files:**
- Modify: `lib/features/preparation/providers/preparation_reminder_providers.dart`
- Test: `test/core/platform/notification_action_channel_test.dart`

**Interfaces:**
- Produces:
  - 常量 `const notificationActionChannel = MethodChannel('com.example.scho_navi/notification_actions');`
  - 在 `preparationReminderSyncProvider`（或新 `notificationActionHandlerProvider`）中注册 `setMethodCallHandler`，处理 `completeNotificationTask(planId, taskId)` → 调 `CompleteNotificationTaskUseCase` → 返回 `{status, snapshotJson}` 或 Flutter error
- Consumes: Task 3 的 `CompleteNotificationTaskUseCase`，`preparationReminderStoreProvider`（activityDays）、`preparationPlanRepositoryProvider`、`preparationReminderPlatformProvider`（用于完成后 syncSnapshot）

- [ ] **Step 1: Write failing test**

`test/core/platform/notification_action_channel_test.dart`：

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/domain/repositories/preparation_plan_repository.dart';
import 'package:scho_navi/domain/services/preparation_reminder_builder.dart';
import 'package:scho_navi/features/preparation/providers/preparation_reminder_providers.dart';
import 'package:scho_navi/features/preparation/services/complete_notification_task_use_case.dart';

class _FakeRepo implements PreparationPlanRepository {
  _FakeRepo(this._plans);
  final List<PreparationPlan> _plans;
  @override
  List<PreparationPlan> list() => _plans;
  @override
  PreparationPlan? findById(String id) =>
      _plans.where((p) => p.id == id).firstOrNull;
  @override
  PreparationPlan? activeForCompetition(String competitionId) => null;
  @override
  Stream<List<PreparationPlan>> watch() => const Stream.empty();
  @override
  Future<PreparationPlan> save(PreparationPlan plan) async {
    final i = _plans.indexWhere((p) => p.id == plan.id);
    if (i >= 0) _plans[i] = plan;
    return plan;
  }
  @override
  Future<void> archive(String id) async {}
  @override
  Future<void> delete(String id) async {}
}

PreparationTask _t(String id) => PreparationTask(
      id: id,
      title: 't$id',
      kind: PreparationTaskKind.required,
      estimatedHours: 1,
      dueDate: DateTime(2026, 7, 2),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('handler returns completed payload with snapshotJson', () async {
    final plans = [
      PreparationPlan(
        id: 'p1',
        competition: CompetitionSnapshot(
          id: 'c1', name: 'X', category: '计算机类',
          rulesSummary: const CompetitionRulesSummary(
            signupTime: '', contestTime: '', teamSize: '', format: '', organizer: ''),
        ),
        targetDate: DateTime(2026, 8, 15),
        weeklyCommitment: WeeklyCommitment.hours6to10,
        experienceLevel: ExperienceLevel.beginner,
        status: PreparationPlanStatus.active,
        phases: [
          PreparationPhase(
            key: 'p', title: '阶段',
            startDate: DateTime(2026, 6, 1), endDate: DateTime(2026, 7, 31),
            tasks: [_t('t1')],
          ),
        ],
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      ),
    ];
    final repo = _FakeRepo(plans);
    final useCase = CompleteNotificationTaskUseCase(
      repository: repo,
      builder: const PreparationReminderBuilder(),
      activityDays: const {},
      now: () => DateTime(2026, 7, 2, 12),
    );
    final handler = buildNotificationActionHandler(useCase);

    final binding = TestDefaultBinaryMessengerBinding.ensureInitialized() as TestDefaultBinaryMessengerBinding;
    // Simulate native call
    Future<void> invoke() async {
      await ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.example.scho_navi/notification_actions',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('completeNotificationTask', {'planId': 'p1', 'taskId': 't1'}),
        ),
        (ByteData? data) {},
      );
    }

    // 直接调用 handler 验证契约
    final result = await handler(MethodCall('completeNotificationTask', {'planId': 'p1', 'taskId': 't1'}));
    expect(result, isA<Map>());
    expect((result as Map)['status'], 'completed');
    expect((result['snapshotJson'] as String).contains('"schemaVersion":3'), isTrue);
  });

  test('handler returns error for missing plan', () async {
    final repo = _FakeRepo([]);
    final useCase = CompleteNotificationTaskUseCase(
      repository: repo,
      builder: const PreparationReminderBuilder(),
      activityDays: const {},
      now: () => DateTime(2026, 7, 2, 12),
    );
    final handler = buildNotificationActionHandler(useCase);
    expect(
      () => handler(MethodCall('completeNotificationTask', {'planId': 'x', 'taskId': 'y'})),
      throwsA(isA<PlatformException>()),
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/platform/notification_action_channel_test.dart`
Expected: FAIL — `buildNotificationActionHandler` 未定义、`notificationActionChannel` 未导出。

- [ ] **Step 3: Implement handler**

在 `lib/features/preparation/providers/preparation_reminder_providers.dart` 顶部 import 后新增：

```dart
import 'dart:convert';

import 'package:flutter/services.dart';

const MethodChannel notificationActionChannel =
    MethodChannel('com.example.scho_navi/notification_actions');

typedef NotificationActionHandler = Future<dynamic> Function(MethodCall call);

NotificationActionHandler buildNotificationActionHandler(
  CompleteNotificationTaskUseCase useCase,
) {
  return (MethodCall call) async {
    if (call.method != 'completeNotificationTask') {
      throw PlatformException(code: 'unimplemented', message: 'unknown method ${call.method}');
    }
    final args = (call.arguments as Map?) ?? const <String, dynamic>{};
    final planId = args['planId'] as String?;
    final taskId = args['taskId'] as String?;
    if (planId == null || taskId == null) {
      throw PlatformException(code: 'invalid_arguments', message: 'planId/taskId required');
    }
    final outcome = await useCase.call(planId: planId, taskId: taskId);
    switch (outcome.result) {
      case CompleteTaskResult.completed:
        return {
          'status': 'completed',
          'snapshotJson': jsonEncode(outcome.snapshot!.toJson()),
        };
      case CompleteTaskResult.alreadyCompleted:
        return {
          'status': 'already_completed',
          'snapshotJson': jsonEncode(outcome.snapshot!.toJson()),
        };
      case CompleteTaskResult.notFound:
        throw PlatformException(code: 'not_found', message: 'plan or task not found');
      case CompleteTaskResult.conflict:
        throw PlatformException(code: 'conflict', message: 'CAS retry exhausted');
      case CompleteTaskResult.persistenceFailed:
        throw PlatformException(code: 'persistence_failed', message: 'save failed');
    }
  };
}
```

并增加 import：
```dart
import '../services/complete_notification_task_use_case.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/platform/notification_action_channel_test.dart`
Expected: 2 个测试 PASS。

- [ ] **Step 5: Wire handler into provider（注册到 channel）**

在 `preparation_reminder_providers.dart` 的 `preparationReminderSyncProvider` 内部，在 `subscription` 之后追加 UI engine handler 注册（用 `ref.onDispose` 注销）：

```dart
  // UI engine: register reverse action channel handler.
  final actionUseCase = CompleteNotificationTaskUseCase(
    repository: repository,
    builder: const PreparationReminderBuilder(),
    activityDays: store.loadActivityDays(),
    now: DateTime.now,
  );
  notificationActionChannel.setMethodCallHandler(
    buildNotificationActionHandler(actionUseCase),
  );
  ref.onDispose(() {
    notificationActionChannel.setMethodCallHandler(null);
  });
```

> 注意：headless engine 在 Task 8 用独立 entrypoint 注册同一 channel，single-flight 由原生 `NotificationActionCoordinator` 保证（避免 UI 与 headless 同时处理）。

- [ ] **Step 6: analyze + commit**

```bash
flutter analyze lib/features/preparation/providers/preparation_reminder_providers.dart
flutter test test/core/platform/notification_action_channel_test.dart
git add lib/features/preparation/providers/preparation_reminder_providers.dart test/core/platform/notification_action_channel_test.dart
git commit -m "feat(reminder): notification_actions 反向通道 Dart handler"
```

---

## Task 5: headless entrypoint `notificationActionMain`

**Files:**
- Modify: `lib/main.dart`
- Test: `test/core/platform/notification_action_channel_test.dart`（追加 headless 启动用例，或新增 `test/main_notification_action_test.dart`）

**Interfaces:**
- Produces: `@pragma('vm:entry-point') void notificationActionMain()` —— 不调 `runApp()`，初始化最小依赖（SharedPreferences、LocalStore、LocalPreparationPlanRepository、PreparationReminderBuilder、CompleteNotificationTaskUseCase），注册 `notificationActionChannel` handler，处理后自动由原生销毁 engine。

- [ ] **Step 1: Write failing test**

`test/main_notification_action_test.dart`：

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/storage/shared_preferences_local_store.dart';
import 'package:scho_navi/data/local/local_preparation_plan_repository.dart';
import 'package:scho_navi/data/local/preparation_reminder_store.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/providers/preparation_reminder_providers.dart';
import 'package:scho_navi/main.dart';

void main() {
  test('notificationActionMain registers handler without runApp', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'competition_preparation_plans.v2': [
        {
          'id': 'p1',
          'competition': {
            'id': 'c1', 'name': 'X', 'category': '计算机类',
            'rules_summary': {'signup_time': '', 'contest_time': '', 'team_size': '', 'format': '', 'organizer': ''},
          },
          'target_date': '2026-08-15T00:00:00.000',
          'timeline_type': 'submission',
          'revision': 0,
          'weekly_commitment': 'hours6to10',
          'experience_level': 'beginner',
          'status': 'active',
          'phases': [{
            'key': 'p', 'title': '阶段',
            'start_date': '2026-06-01T00:00:00.000', 'end_date': '2026-07-31T00:00:00.000',
            'tasks': [{
              'id': 't1', 'title': 't1', 'kind': 'required',
              'estimated_hours': 1, 'due_date': '2026-07-02T00:00:00.000',
            }],
          }],
          'created_at': '2026-06-01T00:00:00.000',
          'updated_at': '2026-06-01T00:00:00.000',
          'tight_schedule': false,
          'overload': false,
        },
      ],
    });

    notificationActionMain();

    // 调用 handler 验证可用
    final result = await notificationActionChannel.invokeMethod<dynamic>(
      'completeNotificationTask',
      {'planId': 'p1', 'taskId': 't1'},
    );
    expect((result as Map)['status'], 'completed');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/main_notification_action_test.dart`
Expected: FAIL — `notificationActionMain` 未定义。

- [ ] **Step 3: Implement entrypoint**

在 `lib/main.dart` 末尾追加：

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'core/storage/shared_preferences_local_store.dart';
import 'data/local/local_preparation_plan_repository.dart';
import 'data/local/preparation_reminder_store.dart';
import 'domain/services/preparation_reminder_builder.dart';
import 'features/preparation/providers/preparation_reminder_providers.dart';
import 'features/preparation/services/complete_notification_task_use_case.dart';

@pragma('vm:entry-point')
void notificationActionMain() {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.getInstance().then((prefs) {
    final store = SharedPreferencesLocalStore(prefs);
    final repo = LocalPreparationPlanRepository(store);
    final reminderStore = PreparationReminderStore(store);
    final useCase = CompleteNotificationTaskUseCase(
      repository: repo,
      builder: const PreparationReminderBuilder(),
      activityDays: reminderStore.loadActivityDays(),
      now: DateTime.now,
    );
    notificationActionChannel.setMethodCallHandler(
      buildNotificationActionHandler(useCase),
    );
  });
}
```

> `SharedPreferencesLocalStore` 构造签名需与 `lib/core/storage/shared_preferences_local_store.dart` 实际签名一致——若构造参数不同（例如需要 `prefs` 字段名不同），实现时按实际签名调整。先 Read 确认（见 Step 3a）。

- [ ] **Step 3a: 确认 SharedPreferencesLocalStore 构造签名**

Run: `grep -n "class SharedPreferencesLocalStore" lib/core/storage/shared_preferences_local_store.dart`

若签名为 `SharedPreferencesLocalStore(this._prefs)` 或 `SharedPreferencesLocalStore(SharedPreferences prefs)`，则上面调用 `SharedPreferencesLocalStore(prefs)` 正确。若需命名参数，调整为 `SharedPreferencesLocalStore(prefs: prefs)`。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/main_notification_action_test.dart`
Expected: PASS。

- [ ] **Step 5: analyze + commit**

```bash
flutter analyze lib/main.dart
git add lib/main.dart test/main_notification_action_test.dart
git commit -m "feat(reminder): headless entrypoint notificationActionMain"
```

---

## Task 6: Android — ReminderStorage v3 解析 + ReminderAlarmRegistry

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/scho_navi/ReminderStorage.kt`
- Test: `android/app/src/test/kotlin/com/example/scho_navi/ReminderStorageTest.kt`（新增 JVM 测试目录）

**Interfaces:**
- Produces:
  - `data class ReminderTask(val taskId, val title, val dueIsoDay, val sortOrder)`
  - 在 `ReminderPlan` 加 `pendingTasks: List<ReminderTask>`
  - `data class DeadlineAlert(val planId, val competitionName, val alertIsoDay, val daysBefore, val deadlineIsoDay)`
  - 在 `ReminderSnapshot` 加 `deadlineAlerts: List<DeadlineAlert>`
  - `data class AlarmRegistryEntry(val isoDay: String, val dataUri: String)` + `snooze: List<SnoozeRegistryEntry>(planId, taskId, triggerAtEpochMs, dataUri)`
  - `object ReminderAlarmRegistry`：`load(context)`, `save(context, deadlineEntries, snoozeEntries)`, `clearAll(context)`
  - `loadSnapshot` 解析 v3，v1/v2 仍兼容（pendingTasks/deadlineAlerts 默认空），未知 schema 返回空

- [ ] **Step 1: Create test directory + write failing test**

创建 `android/app/src/test/kotlin/com/example/scho_navi/ReminderStorageTest.kt`：

```kotlin
package com.example.scho_navi

import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.junit.Assert.*

// 注意：本计划 §9.2 声明不引入 Robolectric。但 ReminderStorage 依赖 Context
// 的 SharedPreferences。改为提取纯解析函数（不依赖 Context）后再测，见 Step 3。
// 此处先写对纯解析函数的测试。
@RunWith(RobolectricTestRunner::class) // 占位——实际改用纯函数，见下
class ReminderStorageTest {
    @Test
    fun parse_v3_snapshot_with_pendingTasks_and_deadlineAlerts() {
        val json = """
        {"schemaVersion":3,"generatedAt":"2026-07-02T12:00:00","currentStreak":1,
         "preparedToday":true,"lastActivityDay":"2026-07-01",
         "plans":[{"planId":"p1","competitionName":"X","targetDate":"2026-08-15",
           "currentPhase":"阶段","completedTasks":0,"totalTasks":2,
           "nextTaskTitle":"t1","nextTaskDueDate":"2026-07-02",
           "pendingTasks":[{"taskId":"t1","title":"t1","dueIsoDay":"2026-07-02","sortOrder":0}]}],
         "deadlineAlerts":[{"planId":"p1","competitionName":"X","alertIsoDay":"2026-08-08",
           "daysBefore":7,"deadlineIsoDay":"2026-08-15"}]}
        """.trimIndent()
        val snapshot = ReminderStorage.parseSnapshotJson(json)
        assertEquals(3, snapshot.schemaVersion)
        assertEquals(1, snapshot.plans.first().pendingTasks.size)
        assertEquals("t1", snapshot.plans.first().pendingTasks.first().taskId)
        assertEquals(1, snapshot.deadlineAlerts.size)
        assertEquals(7, snapshot.deadlineAlerts.first().daysBefore)
    }

    @Test
    fun parse_v2_still_works_with_empty_new_fields() {
        val json = """{"schemaVersion":2,"generatedAt":"2026-07-02T12:00:00","currentStreak":0,
         "preparedToday":false,"plans":[]}"""
        val snapshot = ReminderStorage.parseSnapshotJson(json)
        assertEquals(2, snapshot.schemaVersion)
        assertTrue(snapshot.plans.isEmpty())
        assertTrue(snapshot.deadlineAlerts.isEmpty())
    }

    @Test
    fun parse_unknown_schema_returns_empty() {
        val json = """{"schemaVersion":99}"""
        val snapshot = ReminderStorage.parseSnapshotJson(json)
        assertTrue(snapshot.plans.isEmpty())
        assertTrue(snapshot.deadlineAlerts.isEmpty())
    }
}
```

> **不引入 Robolectric**：改为把解析逻辑提取为 `ReminderStorage.parseSnapshotJson(json: String): ReminderSnapshot` 纯函数（不依赖 Context），`loadSnapshot(context)` 调用它。测试不依赖 Robolectric——删除 `@RunWith` 与 import。最终测试文件：

```kotlin
package com.example.scho_navi

import org.junit.Test
import org.junit.Assert.*

class ReminderStorageTest {
    @Test
    fun parse_v3_snapshot_with_pendingTasks_and_deadlineAlerts() {
        val json = """{"schemaVersion":3,"generatedAt":"2026-07-02T12:00:00","currentStreak":1,"preparedToday":true,"lastActivityDay":"2026-07-01","plans":[{"planId":"p1","competitionName":"X","targetDate":"2026-08-15","currentPhase":"阶段","completedTasks":0,"totalTasks":2,"nextTaskTitle":"t1","nextTaskDueDate":"2026-07-02","pendingTasks":[{"taskId":"t1","title":"t1","dueIsoDay":"2026-07-02","sortOrder":0}]}],"deadlineAlerts":[{"planId":"p1","competitionName":"X","alertIsoDay":"2026-08-08","daysBefore":7,"deadlineIsoDay":"2026-08-15"}]}"""
        val snapshot = ReminderStorage.parseSnapshotJson(json)
        assertEquals(3, snapshot.schemaVersion)
        assertEquals(1, snapshot.plans.first().pendingTasks.size)
        assertEquals(1, snapshot.deadlineAlerts.size)
        assertEquals(7, snapshot.deadlineAlerts.first().daysBefore)
    }

    @Test
    fun parse_v2_still_works_with_empty_new_fields() {
        val json = """{"schemaVersion":2,"generatedAt":"2026-07-02T12:00:00","currentStreak":0,"preparedToday":false,"plans":[]}"""
        val snapshot = ReminderStorage.parseSnapshotJson(json)
        assertEquals(2, snapshot.schemaVersion)
        assertTrue(snapshot.plans.isEmpty())
        assertTrue(snapshot.deadlineAlerts.isEmpty())
    }

    @Test
    fun parse_unknown_schema_returns_empty() {
        val snapshot = ReminderStorage.parseSnapshotJson("""{"schemaVersion":99}""")
        assertTrue(snapshot.plans.isEmpty())
        assertTrue(snapshot.deadlineAlerts.isEmpty())
    }
}
```

- [ ] **Step 2: 配置 JVM 测试**

在 `android/app/build.gradle.kts`（或 `.gradle`）确认 `testImplementation` 含 JUnit。若未有：

```kotlin
dependencies {
    testImplementation("junit:junit:4.13.2")
}
```

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "com.example.scho_navi.ReminderStorageTest"`
Expected: FAIL — `parseSnapshotJson` 不存在。

- [ ] **Step 3: Implement storage**

修改 `android/app/src/main/kotlin/com/example/scho_navi/ReminderStorage.kt`：

新增数据类（顶部）：

```kotlin
data class ReminderTask(
    val taskId: String,
    val title: String,
    val dueIsoDay: String,
    val sortOrder: Int,
)

data class DeadlineAlert(
    val planId: String,
    val competitionName: String,
    val alertIsoDay: String,
    val daysBefore: Int,
    val deadlineIsoDay: String,
)

data class AlarmRegistryEntry(val isoDay: String, val dataUri: String)
data class SnoozeRegistryEntry(
    val planId: String,
    val taskId: String,
    val triggerAtEpochMs: Long,
    val dataUri: String,
)
```

在 `ReminderPlan` 加 `val pendingTasks: List<ReminderTask> = emptyList()`。
在 `ReminderSnapshot` 加 `val deadlineAlerts: List<DeadlineAlert> = emptyList()` 和 `val schemaVersion: Int = 0`。

把 `loadSnapshot` 的解析体提取为纯函数 `parseSnapshotJson(json: String): ReminderSnapshot`：

```kotlin
    fun parseSnapshotJson(raw: String): ReminderSnapshot {
        return try {
            val root = JSONObject(raw)
            val schema = root.optInt("schemaVersion", 0)
            if (schema !in 1..3) return ReminderSnapshot(0, null, emptyList(), emptyList(), 0)
            // ... 原 plans 解析（新增 pendingTasks 解析）...
            val plansJson = root.optJSONArray("plans")
            val plans = buildList { /* 同原逻辑，每个 plan 解析 pendingTasks */ }
            val alertsJson = root.optJSONArray("deadlineAlerts")
            val alerts = buildList {
                if (alertsJson != null) {
                    for (i in 0 until alertsJson.length()) {
                        val a = alertsJson.optJSONObject(i) ?: continue
                        add(DeadlineAlert(
                            planId = a.optString("planId"),
                            competitionName = a.optString("competitionName"),
                            alertIsoDay = a.optString("alertIsoDay"),
                            daysBefore = a.optInt("daysBefore"),
                            deadlineIsoDay = a.optString("deadlineIsoDay"),
                        ))
                    }
                }
            }
            ReminderSnapshot(
                currentStreak = root.optInt("currentStreak"),
                lastActivityDay = root.optString("lastActivityDay").ifBlank { null },
                plans = plans,
                deadlineAlerts = alerts,
                schemaVersion = schema,
            )
        } catch (_: Exception) {
            ReminderSnapshot(0, null, emptyList(), emptyList(), 0)
        }
    }
```

`loadSnapshot(context)` 改为读 prefs 后调 `parseSnapshotJson`。

新增 `ReminderAlarmRegistry`：

```kotlin
object ReminderAlarmRegistry {
    private const val KEY = "alarm_registry"
    private const val DEADLINE = "deadline_entries_json"
    private const val SNOOZE = "snooze_entries_json"

    fun loadDeadline(context: Context): List<AlarmRegistryEntry> =
        loadList(context, DEADLINE, ::parseDeadline)
    fun loadSnooze(context: Context): List<SnoozeRegistryEntry> =
        loadList(context, SNOOZE, ::parseSnooze)
    fun save(context: Context, deadline: List<AlarmRegistryEntry>, snooze: List<SnoozeRegistryEntry>) {
        val prefs = context.getSharedPreferences(KEY, Context.MODE_PRIVATE).edit()
        prefs.putString(DEADLINE, deadline.joinToString("|") { "${it.isoDay}\t${it.dataUri}" })
        prefs.putString(SNOOZE, snooze.joinToString("|") { "${it.planId}\t${it.taskId}\t${it.triggerAtEpochMs}\t${it.dataUri}" })
        prefs.apply()
    }
    fun clearAll(context: Context) {
        context.getSharedPreferences(KEY, Context.MODE_PRIVATE).edit().clear().apply()
    }

    private fun parseDeadline(s: String): AlarmRegistryEntry? {
        val parts = s.split("\t")
        if (parts.size != 2) return null
        return AlarmRegistryEntry(parts[0], parts[1])
    }
    private fun parseSnooze(s: String): SnoozeRegistryEntry? {
        val parts = s.split("\t")
        if (parts.size != 4) return null
        return SnoozeRegistryEntry(parts[0], parts[1], parts[2].toLongOrNull() ?: return null, parts[3])
    }
    private fun <T> loadList(context: Context, key: String, parse: (String) -> T?): List<T> {
        val raw = context.getSharedPreferences(KEY, Context.MODE_PRIVATE).getString(key, null) ?: return emptyList()
        return raw.split("|").mapNotNull(parse)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "com.example.scho_navi.ReminderStorageTest"`
Expected: 3 个测试 PASS。

- [ ] **Step 5: commit**

```bash
git add android/app/src/main/kotlin/com/example/scho_navi/ReminderStorage.kt android/app/src/test/kotlin/com/example/scho_navi/ReminderStorageTest.kt android/app/build.gradle.kts
git commit -m "feat(android): ReminderStorage v3 解析 + ReminderAlarmRegistry"
```

---

## Task 7: Android — ReminderNotificationFactory (channels + groups + tag)

**Files:**
- Create: `android/app/src/main/kotlin/com/example/scho_navi/ReminderNotificationFactory.kt`

**Interfaces:**
- Produces:
  - `object ReminderNotificationFactory`
  - 常量：`CHANNEL_PREPARATION = "preparation_tasks"`, `CHANNEL_DEADLINES = "competition_deadlines"`, `CHANNEL_MENTOR = "mentor_consultations"`
  - 常量：`GROUP_PREPARATION = "scho_navi.preparation"`, `GROUP_DEADLINES = "scho_navi.deadlines"`
  - 常量：`LEGACY_CHANNEL = "preparation_reminders"`（升级后删除）
  - 通知 id：`TASK_NOTIFICATION_ID = 4104`, `PREPARATION_SUMMARY_ID = 4100`, `DEADLINE_NOTIFICATION_ID = 4200`, `DEADLINE_SUMMARY_ID = 4201`
  - tag helper：`taskTag(planId, taskId) = "task:$planId:$taskId"`, `deadlineTag(planId, daysBefore) = "deadline:$planId:$daysBefore"`
  - `fun ensureChannels(context)`：创建 3 个 channel + 删除 legacy channel
  - `fun buildTaskNotification(context, plan, task, actionIntents)`, `buildPreparationSummary(context, digest)`, `buildDeadlineChild(context, alert, viewIntent)`, `buildDeadlineSummary(context, alertIsoDay, count)`

- [ ] **Step 1: Implement factory（无 JVM 测试，靠 Task 11 手动验证）**

`android/app/src/main/kotlin/com/example/scho_navi/ReminderNotificationFactory.kt`：

```kotlin
package com.example.scho_navi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build

object ReminderNotificationFactory {
    const val CHANNEL_PREPARATION = "preparation_tasks"
    const val CHANNEL_DEADLINES = "competition_deadlines"
    const val CHANNEL_MENTOR = "mentor_consultations"
    private const val LEGACY_CHANNEL = "preparation_reminders"

    const val GROUP_PREPARATION = "scho_navi.preparation"
    const val GROUP_DEADLINES = "scho_navi.deadlines"

    const val TASK_NOTIFICATION_ID = 4104
    const val PREPARATION_SUMMARY_ID = 4100
    const val DEADLINE_NOTIFICATION_ID = 4200
    const val DEADLINE_SUMMARY_ID = 4201

    fun taskTag(planId: String, taskId: String) = "task:$planId:$taskId"
    fun deadlineTag(planId: String, daysBefore: Int) = "deadline:$planId:$daysBefore"

    fun ensureChannels(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_PREPARATION, "备赛任务", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "每日备赛任务提醒与摘要"
            }
        )
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_DEADLINES, "竞赛截止", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "竞赛截止前 7/3/0 天提醒"
            }
        )
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_MENTOR, "导师咨询", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "导师咨询相关提醒（预留）"
            }
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.deleteNotificationChannel(LEGACY_CHANNEL)
        }
    }

    fun buildTaskNotification(
        context: Context,
        plan: ReminderPlan,
        task: ReminderTask,
        completeIntent: PendingIntent,
        snoozeIntent: PendingIntent,
        viewIntent: PendingIntent,
    ): Notification {
        val body = "下一项：${task.title} · ${task.dueIsoDay}"
        return Notification.Builder(context, CHANNEL_PREPARATION)
            .setSmallIcon(R.drawable.ic_reminder_notification)
            .setContentTitle("今晚推进「${plan.competitionName}」")
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(viewIntent)
            .setGroup(GROUP_PREPARATION)
            .setGroupAlertBehavior(Notification.GROUP_ALERT_SUMMARY)
            .addAction(R.drawable.ic_reminder_notification, "完成此任务", completeIntent)
            .addAction(R.drawable.ic_reminder_notification, "稍后提醒", snoozeIntent)
            .addAction(R.drawable.ic_reminder_notification, "查看计划", viewIntent)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .build()
    }

    fun buildPreparationSummary(
        context: Context,
        remainingToday: Int,
        upcomingDeadlines: Int,
        nearestDeadlineName: String?,
        nearestDeadlineDay: String?,
    ): Notification {
        val deadlineText = nearestDeadlineName?.let { "最近截止竞赛 $it${nearestDeadlineDay?.let { d -> " · $d" } ?: ""}" } ?: "暂无近期截止"
        val body = "今天还有 $remainingToday 个任务 · $deadlineText · 未来 30 天 $upcomingDeadlines 个截止"
        return Notification.Builder(context, CHANNEL_PREPARATION)
            .setSmallIcon(R.drawable.ic_reminder_notification)
            .setContentTitle("今日备赛摘要")
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setGroup(GROUP_PREPARATION)
            .setGroupSummary(true)
            .setAutoCancel(true)
            .build()
    }

    fun buildDeadlineChild(
        context: Context,
        alert: DeadlineAlert,
        viewIntent: PendingIntent,
    ): Notification {
        val dayText = if (alert.daysBefore == 0) "今天截止" else "还有 ${alert.daysBefore} 天截止"
        val body = "${alert.competitionName} · $dayText（${alert.deadlineIsoDay}）"
        return Notification.Builder(context, CHANNEL_DEADLINES)
            .setSmallIcon(R.drawable.ic_reminder_notification)
            .setContentTitle("竞赛截止提醒")
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(viewIntent)
            .setGroup(GROUP_DEADLINES)
            .setGroupAlertBehavior(Notification.GROUP_ALERT_CHILDREN)
            .addAction(R.drawable.ic_reminder_notification, "查看计划", viewIntent)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .build()
    }

    fun buildDeadlineSummary(context: Context, alertIsoDay: String, count: Int): Notification {
        val body = "$count 个竞赛截止提醒"
        return Notification.Builder(context, CHANNEL_DEADLINES)
            .setSmallIcon(R.drawable.ic_reminder_notification)
            .setContentTitle("竞赛截止")
            .setContentText(body)
            .setGroup(GROUP_DEADLINES)
            .setGroupSummary(true)
            .setAutoCancel(true)
            .build()
    }
}
```

- [ ] **Step 2: analyze（lint）+ commit**

```bash
cd android && ./gradlew :app:lint
git add android/app/src/main/kotlin/com/example/scho_navi/ReminderNotificationFactory.kt
git commit -m "feat(android): ReminderNotificationFactory 通道+分组+tag"
```

---

## Task 8: Android — DailyReminderReceiver（拆分原 ReminderReceiver）

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/scho_navi/ReminderScheduler.kt`
- Test: 手动验证（Task 11）

**Interfaces:**
- Produces:
  - `DailyReminderReceiver`：触发后调 `ReminderScheduler.apply()` 排下一次；从 snapshot 选最紧急 plan/task；投影当日 digest；发任务通知 + 摘要通知
  - `ReminderScheduler.pendingIntent(context)` 改为固定 data URI `schonavi://alarm/daily`
  - 纯函数 `ReminderDigest.project(snapshot, today): Digest` 可 JVM 测试

- [ ] **Step 1: Write JVM test for digest projection**

`android/app/src/test/kotlin/com/example/scho_navi/ReminderDigestTest.kt`：

```kotlin
package com.example.scho_navi

import org.junit.Test
import org.junit.Assert.*

class ReminderDigestTest {
    private fun task(id: String, due: String) = ReminderTask(id, "t$id", due, 0)
    private fun plan(id: String, target: String, pending: List<ReminderTask>) =
        ReminderPlan(id, "竞赛 $id", target, "阶段", 0, 1, pending.firstOrNull()?.title, pending.firstOrNull()?.dueIsoDay, emptyList(), pending)

    @Test
    fun digest_counts_remainingToday_and_upcoming_and_nearest() {
        val today = java.time.LocalDate.of(2026, 7, 2)
        val snapshot = ReminderSnapshot(
            currentStreak = 1, lastActivityDay = "2026-07-01",
            plans = listOf(
                plan("p1", "2026-08-15", listOf(task("t1", "2026-07-02"), task("t2", "2026-07-03"))),
                plan("p2", "2026-07-20", listOf(task("t3", "2026-07-02"))),
                plan("p3", "2026-06-30", emptyList()), // 过期，不计入 upcoming
            ),
            deadlineAlerts = emptyList(),
            schemaVersion = 3,
        )
        val digest = ReminderDigest.project(snapshot, today)
        assertEquals(2, digest.remainingToday)
        assertEquals(2, digest.upcomingDeadlines) // p1, p2
        assertEquals("竞赛 p2", digest.nearestDeadlineName)
        assertEquals("2026-07-20", digest.nearestDeadlineDay)
    }

    @Test
    fun digest_handles_no_active_plan() {
        val today = java.time.LocalDate.of(2026, 7, 2)
        val snapshot = ReminderSnapshot(0, null, emptyList(), emptyList(), 3)
        val digest = ReminderDigest.project(snapshot, today)
        assertEquals(0, digest.remainingToday)
        assertEquals(0, digest.upcomingDeadlines)
        assertNull(digest.nearestDeadlineName)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "com.example.scho_navi.ReminderDigestTest"`
Expected: FAIL — `ReminderDigest` 未定义。

- [ ] **Step 3: Implement digest + DailyReminderReceiver**

在 `ReminderScheduler.kt` 顶部新增 `ReminderDigest`：

```kotlin
data class Digest(
    val remainingToday: Int,
    val upcomingDeadlines: Int,
    val nearestDeadlineName: String?,
    val nearestDeadlineDay: String?,
)

object ReminderDigest {
    fun project(snapshot: ReminderSnapshot, today: java.time.LocalDate): Digest {
        val todayStr = today.toString()
        var remaining = 0
        var upcoming = 0
        var nearest: ReminderPlan? = null
        for (plan in snapshot.plans) {
            remaining += plan.pendingTasks.count { it.dueIsoDay == todayStr }
            val target = runCatching { java.time.LocalDate.parse(plan.targetDate) }.getOrNull()
            if (target != null && !target.isBefore(today) && target.isBefore(today.plusDays(31))) {
                upcoming++
                if (nearest == null || target.isBefore(runCatching { java.time.LocalDate.parse(nearest!!.targetDate) }.getOrNull())) {
                    nearest = plan
                }
            }
        }
        return Digest(
            remainingToday = remaining,
            upcomingDeadlines = upcoming,
            nearestDeadlineName = nearest?.competitionName,
            nearestDeadlineDay = nearest?.targetDate,
        )
    }
}
```

替换原 `ReminderReceiver` 为 `DailyReminderReceiver`：

```kotlin
class DailyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ReminderScheduler.apply(context)
        val schedule = ReminderStorage.loadSchedule(context)
        if (!schedule.enabled || !canNotify(context)) return
        val snapshot = ReminderStorage.loadSnapshot(context)
        if (snapshot.schemaVersion !in 1..3) return
        ReminderNotificationFactory.ensureChannels(context)

        val today = java.time.LocalDate.now()
        // 选最紧急 plan+task
        val candidate = snapshot.plans
            .filter { it.pendingTasks.isNotEmpty() }
            .minWithOrNull(
                compareBy<ReminderPlan> { it.pendingTasks.first().dueIsoDay }
                    .thenBy { it.pendingTasks.first().sortOrder }
                    .thenBy { it.targetDate }
                    .thenBy { it.planId }
            )

        if (candidate != null) {
            val task = candidate.pendingTasks.first()
            val completeIntent = actionPendingIntent(context, "COMPLETE", candidate.planId, task.taskId)
            val snoozeIntent = actionPendingIntent(context, "SNOOZE", candidate.planId, task.taskId)
            val viewIntent = viewPendingIntent(context, candidate.planId)
            val notification = ReminderNotificationFactory.buildTaskNotification(
                context, candidate, task, completeIntent, snoozeIntent, viewIntent
            )
            context.getSystemService(NotificationManager::class.java)
                .notify(ReminderNotificationFactory.taskTag(candidate.planId, task.taskId),
                    ReminderNotificationFactory.TASK_NOTIFICATION_ID, notification)
        }

        // 摘要
        val digest = ReminderDigest.project(snapshot, today)
        val summary = ReminderNotificationFactory.buildPreparationSummary(
            context, digest.remainingToday, digest.upcomingDeadlines,
            digest.nearestDeadlineName, digest.nearestDeadlineDay
        )
        context.getSystemService(NotificationManager::class.java)
            .notify("summary:preparation", ReminderNotificationFactory.PREPARATION_SUMMARY_ID, summary)
    }

    private fun canNotify(context: Context): Boolean {
        if (!context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()) return false
        return android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    private fun actionPendingIntent(context: Context, action: String, planId: String, taskId: String): PendingIntent {
        val encodedPlan = Uri.encode(planId)
        val encodedTask = Uri.encode(taskId)
        val data = Uri.parse("schonavi://notification/action/$action/$encodedPlan/$encodedTask")
        val intent = Intent(context, ReminderActionReceiver::class.java).apply {
            this.action = "com.example.scho_navi.action.NOTIFICATION_$action"
            setDataAndNormalize(data)
            putExtra("planId", planId)
            putExtra("taskId", taskId)
        }
        return PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun viewPendingIntent(context: Context, planId: String): PendingIntent {
        val route = "/preparation-plans/${Uri.encode(planId)}"
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "com.example.scho_navi.OPEN_REMINDER_$planId"
            putExtra(MainActivity.EXTRA_ROUTE, route)
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context, 4105, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
```

修改 `ReminderScheduler.pendingIntent`：

```kotlin
    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, DailyReminderReceiver::class.java).apply {
            action = ACTION_NOTIFY
            data = Uri.parse("schonavi://alarm/daily")
        }
        return PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
```

> 注意：`setDataAndNormalize` 与固定 `data` 使 PendingIntent identity 唯一，requestCode 退化为 0。

- [ ] **Step 4: Run JVM test to verify it passes**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "com.example.scho_navi.ReminderDigestTest"`
Expected: 2 个测试 PASS。

- [ ] **Step 5: commit**

```bash
git add android/app/src/main/kotlin/com/example/scho_navi/ReminderScheduler.kt android/app/src/test/kotlin/com/example/scho_navi/ReminderDigestTest.kt
git commit -m "feat(android): DailyReminderReceiver + ReminderDigest 投影"
```

---

## Task 9: Android — DeadlineAlarmScheduler + DeadlineAlarmReceiver

**Files:**
- Create: `android/app/src/main/kotlin/com/example/scho_navi/DeadlineAlarmScheduler.kt`
- Test: JVM 测试 `DeadlineAlarmSchedulerLogicTest.kt`（纯函数：按日分组 + future 过滤）

**Interfaces:**
- Produces:
  - `object DeadlineAlarmScheduler { fun apply(context, alerts: List<DeadlineAlert>) }`：按 alertIsoDay 分组，每个 future day 排一个闹钟，registry diff 取消孤儿
  - `class DeadlineAlarmReceiver`：触发后读 snapshot，发该日全部 alerts 子通知 + summary（>=2 时）
  - 纯函数 `groupAlertsByDay(alerts): Map<String, List<DeadlineAlert>>`、`filterFutureDays(days, now): List<String>`

- [ ] **Step 1: Write JVM test**

`android/app/src/test/kotlin/com/example/scho_navi/DeadlineAlarmSchedulerLogicTest.kt`：

```kotlin
package com.example.scho_navi

import org.junit.Test
import org.junit.Assert.*
import java.time.LocalDate
import java.time.ZoneId

class DeadlineAlarmSchedulerLogicTest {
    private fun alert(planId: String, alertDay: String) = DeadlineAlert(planId, "竞赛 $planId", alertDay, 7, "2026-08-15")

    @Test
    fun groups_by_day_and_sorts() {
        val alerts = listOf(
            alert("p1", "2026-08-08"),
            alert("p2", "2026-08-08"),
            alert("p3", "2026-08-12"),
        )
        val grouped = DeadlineAlarmScheduler.groupAlertsByDay(alerts)
        assertEquals(listOf("2026-08-08", "2026-08-12"), grouped.keys.toList())
        assertEquals(2, grouped["2026-08-08"]?.size)
    }

    @Test
    fun filters_future_days_only() {
        val now = LocalDate.of(2026, 8, 7).atTime(9, 0).atZone(ZoneId.systemDefault())
        val days = listOf("2026-08-06", "2026-08-07", "2026-08-08", "2026-08-12")
        val future = DeadlineAlarmScheduler.filterFutureDays(days, now)
        // 2026-08-07 9:00 已过 → 丢弃；08-07 当天 9:00 视为 future 则保留，这里以「严格晚于 now」为准
        assertEquals(listOf("2026-08-08", "2026-08-12"), future)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "com.example.scho_navi.DeadlineAlarmSchedulerLogicTest"`
Expected: FAIL — 未定义。

- [ ] **Step 3: Implement**

`android/app/src/main/kotlin/com/example/scho_navi/DeadlineAlarmScheduler.kt`：

```kotlin
package com.example.scho_navi

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

object DeadlineAlarmScheduler {
    fun groupAlertsByDay(alerts: List<DeadlineAlert>): Map<String, List<DeadlineAlert>> {
        val grouped = alerts.groupBy { it.alertIsoDay }.toSortedMap()
        return grouped
    }

    fun filterFutureDays(days: Collection<String>, now: ZonedDateTime): List<String> {
        return days.filter { day ->
            val target = runCatching {
                LocalDate.parse(day).atTime(9, 0).atZone(now.zone).toInstant()
            }.getOrNull()
            target != null && target.isAfter(now.toInstant())
        }
    }

    fun apply(context: Context, alerts: List<DeadlineAlert>) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val now = ZonedDateTime.now()
        val grouped = groupAlertsByDay(alerts)
        val futureDays = filterFutureDays(grouped.keys, now)

        // diff: 取消 registry 中不在 futureDays 的 deadline
        val oldEntries = ReminderAlarmRegistry.loadDeadline(context)
        for (entry in oldEntries) {
            if (entry.isoDay !in futureDays) {
                alarmManager.cancel(deadlinePendingIntent(context, entry.isoDay))
            }
        }

        // 排新 future
        val newEntries = futureDays.map { AlarmRegistryEntry(it, "schonavi://alarm/deadline/$it") }
        for (isoDay in futureDays) {
            val target = LocalDate.parse(isoDay).atTime(9, 0).atZone(now.zone).toInstant().toEpochMilli()
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                target,
                deadlinePendingIntent(context, isoDay),
            )
        }

        ReminderAlarmRegistry.save(
            context,
            deadline = newEntries,
            snooze = ReminderAlarmRegistry.loadSnooze(context), // 保留 snooze
        )
    }

    private fun deadlinePendingIntent(context: Context, isoDay: String): PendingIntent {
        val intent = Intent(context, DeadlineAlarmReceiver::class.java).apply {
            action = "com.example.scho_navi.action.DEADLINE_ALARM"
            data = Uri.parse("schonavi://alarm/deadline/$isoDay")
            putExtra("alertIsoDay", isoDay)
        }
        return PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

class DeadlineAlarmReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val alertIsoDay = intent.getStringExtra("alertIsoDay") ?: return
        val snapshot = ReminderStorage.loadSnapshot(context)
        if (snapshot.schemaVersion !in 1..3) return
        ReminderNotificationFactory.ensureChannels(context)
        val manager = context.getSystemService(android.app.NotificationManager::class.java)

        val dayAlerts = snapshot.deadlineAlerts.filter { it.alertIsoDay == alertIsoDay }
        if (dayAlerts.isEmpty()) {
            // 清理 registry entry
            return
        }
        for (alert in dayAlerts) {
            val viewIntent = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).apply {
                    action = "com.example.scho_navi.OPEN_DEADLINE_${alert.planId}"
                    putExtra(MainActivity.EXTRA_ROUTE, "/preparation-plans/${Uri.encode(alert.planId)}")
                    flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val notification = ReminderNotificationFactory.buildDeadlineChild(context, alert, viewIntent)
            manager.notify(
                ReminderNotificationFactory.deadlineTag(alert.planId, alert.daysBefore),
                ReminderNotificationFactory.DEADLINE_NOTIFICATION_ID,
                notification,
            )
        }
        if (dayAlerts.size >= 2) {
            val summary = ReminderNotificationFactory.buildDeadlineSummary(context, alertIsoDay, dayAlerts.size)
            manager.notify("summary:deadlines:$alertIsoDay", ReminderNotificationFactory.DEADLINE_SUMMARY_ID, summary)
        }
    }
}
```

- [ ] **Step 4: Run JVM test to verify it passes**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "com.example.scho_navi.DeadlineAlarmSchedulerLogicTest"`
Expected: 2 个测试 PASS。

- [ ] **Step 5: commit**

```bash
git add android/app/src/main/kotlin/com/example/scho_navi/DeadlineAlarmScheduler.kt android/app/src/test/kotlin/com/example/scho_navi/DeadlineAlarmSchedulerLogicTest.kt
git commit -m "feat(android): DeadlineAlarmScheduler 按日批处理 + DeadlineAlarmReceiver"
```

---

## Task 10: Android — ReminderActionReceiver + SnoozedTaskReceiver

**Files:**
- Create: `android/app/src/main/kotlin/com/example/scho_navi/ReminderActionReceiver.kt`
- Test: 手动验证（Task 11）

**Interfaces:**
- Produces:
  - `ReminderActionReceiver`：处理 COMPLETE/SNOOZE，COMPLETE 用 `goAsync()` 调 `NotificationActionCoordinator`，SNOOZE 排 1h 闹钟 + 写 registry
  - `SnoozedTaskReceiver`：1h 后触发，校验 task 仍 pending 后重发任务通知
  - snooze PendingIntent data URI：`schonavi://alarm/snooze/{encodedPlanId}/{encodedTaskId}`

- [ ] **Step 1: Implement**

`android/app/src/main/kotlin/com/example/scho_navi/ReminderActionReceiver.kt`：

```kotlin
package com.example.scho_navi

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import java.time.ZonedDateTime

class ReminderActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val planId = intent.getStringExtra("planId") ?: return
        val taskId = intent.getStringExtra("taskId") ?: return
        val pendingResult = goAsync()

        when {
            action.endsWith("COMPLETE") -> {
                NotificationActionCoordinator.complete(context, planId, taskId,
                    onSuccess = {
                        cancelTaskNotification(context, planId, taskId)
                        pendingResult.finish()
                    },
                    onFailure = { pendingResult.finish() },
                )
            }
            action.endsWith("SNOOZE") -> {
                scheduleSnooze(context, planId, taskId)
                cancelTaskNotification(context, planId, taskId)
                pendingResult.finish()
            }
        }
    }

    private fun scheduleSnooze(context: Context, planId: String, taskId: String) {
        val triggerAt = System.currentTimeMillis() + 60 * 60 * 1000
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAt,
            snoozePendingIntent(context, planId, taskId),
        )
        // 更新 registry（覆盖同 planId+taskId）
        val snoozes = ReminderAlarmRegistry.loadSnooze(context)
            .filterNot { it.planId == planId && it.taskId == taskId } +
            SnoozeRegistryEntry(planId, taskId, triggerAt, "schonavi://alarm/snooze/${Uri.encode(planId)}/${Uri.encode(taskId)}")
        ReminderAlarmRegistry.save(context,
            deadline = ReminderAlarmRegistry.loadDeadline(context),
            snooze = snoozes,
        )
    }

    private fun cancelTaskNotification(context: Context, planId: String, taskId: String) {
        context.getSystemService(android.app.NotificationManager::class.java)
            .cancel(ReminderNotificationFactory.taskTag(planId, taskId),
                ReminderNotificationFactory.TASK_NOTIFICATION_ID)
    }

    companion object {
        fun snoozePendingIntent(context: Context, planId: String, taskId: String): PendingIntent {
            val encodedPlan = Uri.encode(planId)
            val encodedTask = Uri.encode(taskId)
            val intent = Intent(context, SnoozedTaskReceiver::class.java).apply {
                action = "com.example.scho_navi.action.SNOOZE_FIRE"
                data = Uri.parse("schonavi://alarm/snooze/$encodedPlan/$encodedTask")
                putExtra("planId", planId)
                putExtra("taskId", taskId)
            }
            return PendingIntent.getBroadcast(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}

class SnoozedTaskReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val planId = intent.getStringExtra("planId") ?: return
        val taskId = intent.getStringExtra("taskId") ?: return
        val snapshot = ReminderStorage.loadSnapshot(context)
        if (snapshot.schemaVersion !in 1..3) return
        val plan = snapshot.plans.firstOrNull { it.planId == planId } ?: return
        val task = plan.pendingTasks.firstOrNull { it.taskId == taskId } ?: return // 已完成则静默取消
        ReminderNotificationFactory.ensureChannels(context)
        val completeIntent = PendingIntent.getBroadcast(
            context, 0,
            Intent(context, ReminderActionReceiver::class.java).apply {
                action = "com.example.scho_navi.action.NOTIFICATION_COMPLETE"
                data = Uri.parse("schonavi://notification/action/COMPLETE/${Uri.encode(planId)}/${Uri.encode(taskId)}")
                putExtra("planId", planId)
                putExtra("taskId", taskId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val snoozeIntent = PendingIntent.getBroadcast(
            context, 0,
            Intent(context, ReminderActionReceiver::class.java).apply {
                action = "com.example.scho_navi.action.NOTIFICATION_SNOOZE"
                data = Uri.parse("schonavi://notification/action/SNOOZE/${Uri.encode(planId)}/${Uri.encode(taskId)}")
                putExtra("planId", planId)
                putExtra("taskId", taskId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val viewIntent = PendingIntent.getActivity(
            context, 4105,
            Intent(context, MainActivity::class.java).apply {
                action = "com.example.scho_navi.OPEN_REMINDER_$planId"
                putExtra(MainActivity.EXTRA_ROUTE, "/preparation-plans/${Uri.encode(planId)}")
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = ReminderNotificationFactory.buildTaskNotification(
            context, plan, task, completeIntent, snoozeIntent, viewIntent
        )
        context.getSystemService(android.app.NotificationManager::class.java)
            .notify(ReminderNotificationFactory.taskTag(planId, taskId),
                ReminderNotificationFactory.TASK_NOTIFICATION_ID, notification)
        // 清理 snooze registry 中的该条
        val snoozes = ReminderAlarmRegistry.loadSnooze(context)
            .filterNot { it.planId == planId && it.taskId == taskId }
        ReminderAlarmRegistry.save(context,
            deadline = ReminderAlarmRegistry.loadDeadline(context),
            snooze = snoozes,
        )
    }
}
```

- [ ] **Step 2: commit**

```bash
git add android/app/src/main/kotlin/com/example/scho_navi/ReminderActionReceiver.kt
git commit -m "feat(android): ReminderActionReceiver + SnoozedTaskReceiver"
```

---

## Task 11: Android — NotificationActionCoordinator (headless engine + single-flight + 超时)

**Files:**
- Create: `android/app/src/main/kotlin/com/example/scho_navi/NotificationActionCoordinator.kt`

**Interfaces:**
- Produces:
  - `object NotificationActionCoordinator`
  - `fun complete(context, planId, taskId, onSuccess: () -> Unit, onFailure: () -> Unit)`
  - 优先复用 UI engine 的 action channel；不存在时启动 `notificationActionMain` headless engine
  - 进程内 single-flight：同 planId+taskId 只允许一个在途
  - 8 秒超时；成功后 `saveSnapshot` + `DeadlineAlarmScheduler.apply` + 刷新 Widget

- [ ] **Step 1: Implement**

`android/app/src/main/kotlin/com/example/scho_navi/NotificationActionCoordinator.kt`：

```kotlin
package com.example.scho_navi

import android.content.Context
import io.flutter.FlutterEngine
import io.flutter.FlutterEngineCache
import io.flutter.embedding.engine.dartexecutor.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object NotificationActionCoordinator {
    private const val CACHE_ID = "notification_action_engine"
    private const val CHANNEL = "com.example.scho_navi/notification_actions"
    private const val TIMEOUT_MS = 8000L
    private val inFlight = mutableSetOf<String>() // planId|taskId

    private var uiChannel: MethodChannel? = null

    fun registerUiChannel(engine: io.flutter.embedding.engine.FlutterEngine) {
        uiChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
    }
    fun unregisterUiChannel() {
        uiChannel = null
    }

    fun complete(
        context: Context,
        planId: String,
        taskId: String,
        onSuccess: () -> Unit,
        onFailure: () -> Unit,
    ) {
        val key = "$planId|$taskId"
        if (!inFlight.add(key)) { onFailure(); return }

        val channel = uiChannel ?: ensureHeadlessEngine(context)
        if (channel == null) {
            inFlight.remove(key)
            onFailure()
            return
        }

        val handler = MethodChannel.Result {
            if (it is Map<*, *>) {
                val status = it["status"] as? String
                if (status == "completed" || status == "already_completed") {
                    val snapshotJson = it["snapshotJson"] as? String
                    if (snapshotJson != null) {
                        ReminderStorage.saveSnapshot(context, snapshotJson)
                        val snapshot = ReminderStorage.loadSnapshot(context)
                        DeadlineAlarmScheduler.apply(context, snapshot.deadlineAlerts)
                        PreparationWidgetProvider.refreshAll(context)
                    }
                    inFlight.remove(key)
                    onSuccess()
                } else {
                    inFlight.remove(key)
                    onFailure()
                }
            } else {
                inFlight.remove(key)
                onFailure()
            }
        }

        channel.invokeMethod("completeNotificationTask", mapOf("planId" to planId, "taskId" to taskId), handler)

        // 超时
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            if (inFlight.remove(key)) {
                onFailure()
                // 销毁 headless engine（若是我们启动的）
                FlutterEngineCache.getInstance().get(CACHE_ID)?.let {
                    it.destroy()
                    FlutterEngineCache.getInstance().remove(CACHE_ID)
                }
            }
        }, TIMEOUT_MS)
    }

    private fun ensureHeadlessEngine(context: Context): MethodChannel? {
        val existing = FlutterEngineCache.getInstance().get(CACHE_ID)
        if (existing != null) {
            return MethodChannel(existing.dartExecutor.binaryMessenger, CHANNEL)
        }
        return try {
            val engine = FlutterEngine(context)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    context.findAppBundlePath()!!,
                    "notificationActionMain",
                )
            )
            FlutterEngineCache.getInstance().put(CACHE_ID, engine)
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        } catch (_: Exception) {
            null
        }
    }
}
```

- [ ] **Step 2: commit**

```bash
git add android/app/src/main/kotlin/com/example/scho_navi/NotificationActionCoordinator.kt
git commit -m "feat(android): NotificationActionCoordinator headless engine + single-flight"
```

---

## Task 12: Android — MainActivity + Manifest 接线

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/scho_navi/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: MainActivity — 注册 action channel + reconcile**

在 `MainActivity.configureFlutterEngine` 中，`remindersChannel` 设置后追加：

```kotlin
        // 注册 UI engine 的 action channel
        NotificationActionCoordinator.registerUiChannel(flutterEngine)
```

在 `cleanUpFlutterEngine` 追加：

```kotlin
        NotificationActionCoordinator.unregisterUiChannel()
```

在 `onCreate`（`WidgetRotationScheduler.apply(this)` 之后）追加：

```kotlin
        ReminderNotificationFactory.ensureChannels(this)
        val snapshot = ReminderStorage.loadSnapshot(this)
        DeadlineAlarmScheduler.apply(this, snapshot.deadlineAlerts)
        ReminderScheduler.apply(this) // 重排 daily
```

在 `handleReminderCall` 的 `"syncSnapshot"` 分支，`saveSnapshot` 后追加：

```kotlin
                    val snapshot = ReminderStorage.loadSnapshot(this)
                    DeadlineAlarmScheduler.apply(this, snapshot.deadlineAlerts)
```

- [ ] **Step 2: AndroidManifest — 替换 Receiver 注册**

将：

```xml
        <receiver
            android:name=".ReminderReceiver"
            android:exported="false"/>
```

替换为：

```xml
        <receiver
            android:name=".DailyReminderReceiver"
            android:exported="false"/>
        <receiver
            android:name=".DeadlineAlarmReceiver"
            android:exported="false"/>
        <receiver
            android:name=".ReminderActionReceiver"
            android:exported="false"/>
        <receiver
            android:name=".SnoozedTaskReceiver"
            android:exported="false"/>
```

`ReminderRescheduleReceiver` 的 intent-filter 保持不变（BOOT/MY_PACKAGE_REPLACED/TIMEZONE_CHANGED/DATE_CHANGED），但其在 `onReceive` 中需额外重排 deadline + snooze。

- [ ] **Step 3: 改 ReminderRescheduleReceiver.onReceive**

在 `ReminderScheduler.kt` 中：

```kotlin
class ReminderRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ReminderScheduler.apply(context)
        val snapshot = ReminderStorage.loadSnapshot(context)
        DeadlineAlarmScheduler.apply(context, snapshot.deadlineAlerts)
        // 重排未触发的 snooze
        val now = System.currentTimeMillis()
        val snoozes = ReminderAlarmRegistry.loadSnooze(context).filter { it.triggerAtEpochMs > now }
        for (s in snoozes) {
            val pi = ReminderActionReceiver.snoozePendingIntent(context, s.planId, s.taskId)
            context.getSystemService(AlarmManager::class.java)
                .setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, s.triggerAtEpochMs, pi)
        }
        PreparationWidgetProvider.refreshAll(context)
    }
}
```

- [ ] **Step 4: build + analyze**

```bash
cd android && ./gradlew :app:assembleDebug
```
Expected: BUILD SUCCESSFUL。

- [ ] **Step 5: commit**

```bash
git add android/app/src/main/kotlin/com/example/scho_navi/MainActivity.kt android/app/src/main/kotlin/com/example/scho_navi/ReminderScheduler.kt android/app/src/main/AndroidManifest.xml
git commit -m "feat(android): MainActivity 接线 + Manifest 注册新 Receiver"
```

---

## Task 13: 全量验证 + 收尾

**Files:** 无新文件

- [ ] **Step 1: Flutter 全量 analyze + test**

```bash
flutter analyze
flutter test
```
Expected: analyze 0 issues；test 全绿（注意：Drift 测试既有 hang 问题非本次引入，若遇 hang 跳过该文件并标注）。

- [ ] **Step 2: Android JVM 全量 test**

```bash
cd android && ./gradlew :app:testDebugUnitTest
cd ..
```
Expected: 全绿（ReminderStorageTest、ReminderDigestTest、DeadlineAlarmSchedulerLogicTest）。

- [ ] **Step 3: 构建 APK**

```bash
flutter build apk --debug
```
Expected: BUILD SUCCESSFUL。

- [ ] **Step 4: 手动集成验证（按 spec §10 八场景）**

按 [docs/superpowers/specs/2026-07-02-notification-interaction-upgrade-design.md](docs/superpowers/specs/2026-07-02-notification-interaction-upgrade-design.md) §10 执行场景 1–8，记录结果。若某场景失败，回到对应 Task 修复。

- [ ] **Step 5: 记录 AIGC 评分佐证**

截图场景 8（三 channel + 分组 + headless 完成）保存到评分材料目录（用户自定路径）。

- [ ] **Step 6: final commit（若有 fix）**

```bash
git add -A
git commit -m "chore(reminder): 通知交互升级收尾验证"
```

---

## Self-Review

**1. Spec coverage:**
- §1 范围/约束 → Global Constraints 全覆盖 ✓
- §2.1 通道 → Task 7 ✓
- §2.2 分组 → Task 7（group key + summary + alert behavior）✓
- §2.3 Receiver 矩阵 → Task 8/9/10/11 ✓
- §2.4 MethodChannel 方向 → Task 4/5（反向通道）✓
- §3 schema v3 → Task 1/2 ✓
- §4 闹钟调度 + registry → Task 6/9 ✓
- §5 通知生成 → Task 7/8/9 ✓
- §6 动作闭环 → Task 10/11 ✓
- §7 文件改动清单 → 全部 Task 覆盖 ✓
- §8 错误恢复 → 各 Task 错误分支 ✓
- §9 测试 → Task 1–9 含测试，Task 7/10/11 手动验证（§9.3）✓
- §10 验收清单 → Task 13 Step 4 ✓

**2. Placeholder scan:** 无 TBD/TODO；每个代码步含完整代码 ✓

**3. Type consistency:**
- `PreparationReminderTask` 字段名 Dart/Kotlin 一致（taskId/title/dueIsoDay/sortOrder）✓
- `DeadlineAlert` 字段名一致（planId/competitionName/alertIsoDay/daysBefore/deadlineIsoDay）✓
- `CompleteTaskResult` enum 值与 handler switch 一致 ✓
- `ReminderNotificationFactory` 常量在 Task 7/8/9/10 引用一致 ✓
- `NotificationActionCoordinator.complete` 签名在 Task 10/11 一致 ✓
- channel 名 `com.example.scho_navi/notification_actions` 在 Task 4/5/11 一致 ✓
- data URI scheme `schonavi://` 在 Task 8/9/10/11 一致 ✓

**4. 遗留风险（执行时注意）：**
- Task 5 的 `SharedPreferencesLocalStore` 构造签名需 Step 3a 实际确认
- Task 6 JVM 测试目录首次建立，需确认 `build.gradle.kts` testImplementation 配置
- Task 11 headless engine 的 `findAppBundlePath()` 在某些 Flutter 版本可能为 null，需运行时验证
