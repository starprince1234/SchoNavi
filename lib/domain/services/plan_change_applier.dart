import '../../core/calendar_date.dart';
import '../entities/plan_change_card.dart';
import '../entities/preparation_plan.dart';
import 'plan_change_validator.dart';

/// 单张改动卡的原子应用结果（spec §3.6）。
class ApplyResult {
  const ApplyResult({
    this.newPlan,
    required this.applied,
    this.stale = false,
    this.error,
  });

  final PreparationPlan? newPlan;
  final bool applied;
  final bool stale;
  final String? error;

  static const _stale = ApplyResult(applied: false, stale: true);
}

/// 改动卡原子应用器（spec §3.6）。
///
/// 纯领域服务：无副作用、不读写仓库、不持久化。`applyCard` 接收当前计划、
/// 卡与 `expectedRevision`，按类型生成新的不可变计划并返回。版本不一致直接
/// 返回 stale；版本一致后用 [PlanChangeValidator] 对当前计划重新校验该卡，
/// 校验失败返回 `error`。真正的幂等去重（同 changeSetId+cardId 已 applied）
/// 由调用方（P4b.2 controller）负责：`addTask` 的确定性 ID `u_${revision}_${cardId}`
/// 使重复应用可被检测，但 `applyCard` 本身不去重。
class PlanChangeApplier {
  const PlanChangeApplier._();

  /// 原子应用 [card] 到 [plan]。
  ///
  /// [expectedRevision] 是调用方持有的期望版本号（通常为 changeSet 的
  /// `basePlanRevision` 或上一张卡应用后的新 revision）。[calendarToday]
  /// 是本次操作的权威日历基准，用于构造 [PlanSnapshot] 重新校验。
  static ApplyResult applyCard({
    required PreparationPlan plan,
    required PlanChangeCard card,
    required int expectedRevision,
    DateTime? calendarToday,
  }) {
    if (plan.revision != expectedRevision) {
      return ApplyResult._stale;
    }

    final today = calendarToday ?? CalendarDate.normalize(DateTime.now());
    final snapshot = PlanSnapshot.fromPlan(plan, calendarToday: today);
    final validated = PlanChangeValidator.validate(
      PlanChangeSet(
        id: 'single',
        basePlanRevision: plan.revision,
        cards: [card],
      ),
      snapshot,
    ).first;
    if (validated.status == ChangeCardStatus.rejected) {
      return ApplyResult(
        applied: false,
        error: validated.rejectionReason ?? '改动卡被拒绝',
      );
    }

    switch (card.type) {
      case ChangeCardType.moveTask:
        return _applyMoveTask(plan, card);
      case ChangeCardType.addTask:
        return _applyAddTask(plan, card);
      case ChangeCardType.deleteTask:
        return _applyDeleteTask(plan, card);
      case ChangeCardType.reschedulePhase:
        return _applyReschedulePhase(plan, card);
      case ChangeCardType.appendAdvice:
        return _applyAppendAdvice(plan, card);
    }
  }

  // --- moveTask -----------------------------------------------------------

  static ApplyResult _applyMoveTask(PreparationPlan plan, PlanChangeCard card) {
    final newDate = card.newDate!;
    final newPhases = plan.phases.map((phase) {
      final idx = phase.tasks.indexWhere((t) => t.id == card.targetTaskId);
      if (idx < 0) return phase;
      final tasks = List<PreparationTask>.of(phase.tasks);
      tasks[idx] = tasks[idx].copyWith(
        dueDate: CalendarDate.clampDay(
          CalendarDate.normalize(newDate),
          phase.startDate,
          phase.endDate,
        ),
      );
      return phase.copyWith(tasks: tasks);
    }).toList();
    return ApplyResult(
      newPlan: plan.copyWith(phases: newPhases),
      applied: true,
    );
  }

  // --- addTask ------------------------------------------------------------

  static ApplyResult _applyAddTask(PreparationPlan plan, PlanChangeCard card) {
    final draft = card.newTask!;
    final task = PreparationTask(
      id: 'u_${plan.revision}_${card.id}',
      title: draft.title,
      kind: PreparationTaskKind.userAdded,
      estimatedHours: draft.estimatedHours,
      dueDate: CalendarDate.normalize(draft.dueDate),
      note: draft.note,
      completedAt: null,
    );
    final newPhases = plan.phases.map((phase) {
      if (phase.key != card.targetPhaseKey) return phase;
      return phase.copyWith(tasks: [...phase.tasks, task]);
    }).toList();
    return ApplyResult(
      newPlan: plan.copyWith(phases: newPhases),
      applied: true,
    );
  }

  // --- deleteTask ---------------------------------------------------------

  static ApplyResult _applyDeleteTask(PreparationPlan plan, PlanChangeCard card) {
    final newPhases = plan.phases.map((phase) {
      return phase.copyWith(
        tasks: phase.tasks
            .where((t) => t.id != card.targetTaskId)
            .toList(growable: false),
      );
    }).toList();
    return ApplyResult(
      newPlan: plan.copyWith(phases: newPhases),
      applied: true,
    );
  }

  // --- reschedulePhase ----------------------------------------------------

  static ApplyResult _applyReschedulePhase(
    PreparationPlan plan,
    PlanChangeCard card,
  ) {
    final draftByKey = {
      for (final d in card.phaseSchedule!)
          d.phaseKey: PhaseScheduleDraft(
            phaseKey: d.phaseKey,
            startDate: CalendarDate.normalize(d.startDate),
            endDate: CalendarDate.normalize(d.endDate),
          ),
    };
    final newPhases = plan.phases.map((phase) {
      final d = draftByKey[phase.key];
      if (d == null) return phase;
      final start = d.startDate;
      final end = d.endDate;
      final tasks = phase.tasks.map((t) {
        if (t.completed) return t; // 保留已完成任务的 dueDate。
        return t.copyWith(
          dueDate: CalendarDate.clampDay(
            CalendarDate.normalize(t.dueDate),
            start,
            end,
          ),
        );
      }).toList(growable: false);
      return phase.copyWith(
        startDate: start,
        endDate: end,
        tasks: tasks,
      );
    }).toList();
    return ApplyResult(
      newPlan: plan.copyWith(phases: newPhases),
      applied: true,
    );
  }

  // --- appendAdvice -------------------------------------------------------

  static ApplyResult _applyAppendAdvice(
    PreparationPlan plan,
    PlanChangeCard card,
  ) {
    final text = card.adviceText!;
    if (card.targetPhaseKey != null) {
      final newPhases = plan.phases.map((phase) {
        if (phase.key != card.targetPhaseKey) return phase;
        return phase.copyWith(
          personalizedAdvice: _append(phase.personalizedAdvice, text),
        );
      }).toList();
      return ApplyResult(
        newPlan: plan.copyWith(phases: newPhases),
        applied: true,
      );
    }
    return ApplyResult(
      newPlan: plan.copyWith(
        personalizedSummary: _append(plan.personalizedSummary, text),
      ),
      applied: true,
    );
  }

  static String _append(String? existing, String text) =>
      existing == null || existing.isEmpty ? text : '$existing\n$text';
}
