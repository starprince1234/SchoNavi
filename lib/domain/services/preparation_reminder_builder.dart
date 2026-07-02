import '../entities/preparation_plan.dart';
import '../entities/preparation_reminder.dart';

class PreparationReminderBuilder {
  const PreparationReminderBuilder();

  PreparationReminderSnapshot build({
    required List<PreparationPlan> plans,
    required Set<String> activityDays,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final activePlans =
        plans
            .where((plan) => plan.status == PreparationPlanStatus.active)
            .toList()
          ..sort((a, b) {
            final byDate = a.targetDate.compareTo(b.targetDate);
            return byDate != 0 ? byDate : a.id.compareTo(b.id);
          });

    final summaries = activePlans
        .map((plan) => _summary(plan, today))
        .toList(growable: false);
    final normalizedDays = activityDays.toList()..sort();
    final todayKey = _isoDay(today);
    final yesterdayKey = _isoDay(today.subtract(const Duration(days: 1)));
    final preparedToday = activityDays.contains(todayKey);
    final streakEnd = preparedToday
        ? today
        : activityDays.contains(yesterdayKey)
        ? today.subtract(const Duration(days: 1))
        : null;
    var streak = 0;
    if (streakEnd != null) {
      var cursor = streakEnd;
      while (activityDays.contains(_isoDay(cursor))) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }

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

    return PreparationReminderSnapshot(
      generatedAt: now,
      currentStreak: streak,
      preparedToday: preparedToday,
      lastActivityDay: normalizedDays.isEmpty ? null : normalizedDays.last,
      plans: summaries,
      deadlineAlerts: deadlineAlerts,
    );
  }

  PreparationReminderPlanSummary _summary(
    PreparationPlan plan,
    DateTime today,
  ) {
    final tasks = <({PreparationTask task, int order})>[];
    var order = 0;
    for (final phase in plan.phases) {
      for (final task in phase.tasks) {
        tasks.add((task: task, order: order++));
      }
    }
    final incomplete = tasks.where((entry) => !entry.task.completed).toList()
      ..sort((a, b) {
        final byDate = a.task.dueDate.compareTo(b.task.dueDate);
        if (byDate != 0) return byDate;
        final byKind = _kindRank(a.task.kind).compareTo(_kindRank(b.task.kind));
        return byKind != 0 ? byKind : a.order.compareTo(b.order);
      });
    final currentPhase = _currentPhase(plan.phases, today);

    final pendingTasks = [
      for (final entry in incomplete)
        PreparationReminderTask(
          taskId: entry.task.id,
          title: entry.task.title,
          dueIsoDay: _isoDay(entry.task.dueDate),
          sortOrder: 0,
        ),
    ];
    final pendingTasksWithOrder = [
      for (var i = 0; i < pendingTasks.length; i++)
        pendingTasks[i].copyWith(sortOrder: i),
    ];

    final phaseSummaries = plan.phases
        .take(5)
        .map((phase) {
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
        })
        .toList(growable: false);

    return PreparationReminderPlanSummary(
      planId: plan.id,
      competitionName: plan.competition.name,
      targetDate: plan.targetDate,
      currentPhase: currentPhase?.title ?? '准备完成',
      completedTasks: tasks.where((entry) => entry.task.completed).length,
      totalTasks: tasks.length,
      nextTaskTitle: incomplete.isEmpty ? null : incomplete.first.task.title,
      nextTaskDueDate: incomplete.isEmpty
          ? null
          : incomplete.first.task.dueDate,
      phases: phaseSummaries,
      pendingTasks: pendingTasksWithOrder,
    );
  }

  PreparationPhase? _currentPhase(
    List<PreparationPhase> phases,
    DateTime today,
  ) {
    if (phases.isEmpty) return null;
    for (final phase in phases) {
      if (!today.isBefore(_day(phase.startDate)) &&
          !today.isAfter(_day(phase.endDate))) {
        return phase;
      }
    }
    final future = phases.where(
      (phase) => today.isBefore(_day(phase.startDate)),
    );
    if (future.isNotEmpty) return future.first;
    return phases.last;
  }

  int _kindRank(PreparationTaskKind kind) => switch (kind) {
    PreparationTaskKind.required => 0,
    PreparationTaskKind.optional => 1,
    PreparationTaskKind.userAdded => 2,
  };

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  String _isoDay(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
