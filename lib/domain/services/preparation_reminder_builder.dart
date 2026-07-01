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

    return PreparationReminderSnapshot(
      generatedAt: now,
      currentStreak: streak,
      preparedToday: preparedToday,
      lastActivityDay: normalizedDays.isEmpty ? null : normalizedDays.last,
      plans: summaries,
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
