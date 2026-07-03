import '../../../core/error/app_exception.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../domain/entities/preparation_reminder.dart';
import '../../../domain/repositories/preparation_plan_repository.dart';
import '../../../domain/services/preparation_reminder_builder.dart';

enum CompleteTaskResult {
  completed,
  alreadyCompleted,
  notFound,
  conflict,
  persistenceFailed,
}

class CompleteTaskOutcome {
  const CompleteTaskOutcome(this.result, this.snapshot);
  final CompleteTaskResult result;
  final PreparationReminderSnapshot? snapshot;
}

class CompleteNotificationTaskUseCase {
  CompleteNotificationTaskUseCase({
    required this._repository,
    required this._builder,
    required this._activityDays,
    required this._now,
  });

  final PreparationPlanRepository _repository;
  final PreparationReminderBuilder _builder;
  final Set<String> _activityDays;
  final DateTime Function() _now;
  Future<CompleteTaskOutcome> call({
    required String planId,
    required String taskId,
  }) async {
    final plan = _repository.findById(planId);
    if (plan == null) {
      return const CompleteTaskOutcome(CompleteTaskResult.notFound, null);
    }

    final task = _findTask(plan, taskId);
    if (task == null) {
      return const CompleteTaskOutcome(CompleteTaskResult.notFound, null);
    }
    if (task.completed) {
      return CompleteTaskOutcome(
        CompleteTaskResult.alreadyCompleted,
        _buildSnapshot(),
      );
    }

    final updatedPlan = _replaceTask(
      plan,
      task.id,
      task.copyWith(completedAt: _now()),
    );
    try {
      await _repository.save(updatedPlan);
    } on ConflictException {
      final fresh = _repository.findById(planId);
      if (fresh == null) {
        return const CompleteTaskOutcome(CompleteTaskResult.notFound, null);
      }
      final freshTask = _findTask(fresh, taskId);
      if (freshTask == null) {
        return const CompleteTaskOutcome(CompleteTaskResult.notFound, null);
      }
      if (freshTask.completed) {
        return CompleteTaskOutcome(
          CompleteTaskResult.alreadyCompleted,
          _buildSnapshot(),
        );
      }
      final retryPlan = _replaceTask(
        fresh,
        freshTask.id,
        freshTask.copyWith(completedAt: _now()),
      );
      try {
        await _repository.save(retryPlan);
      } on ConflictException {
        return const CompleteTaskOutcome(CompleteTaskResult.conflict, null);
      } catch (_) {
        return const CompleteTaskOutcome(
          CompleteTaskResult.persistenceFailed,
          null,
        );
      }
    } catch (_) {
      return const CompleteTaskOutcome(
        CompleteTaskResult.persistenceFailed,
        null,
      );
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

  PreparationPlan _replaceTask(
    PreparationPlan plan,
    String taskId,
    PreparationTask updated,
  ) {
    return plan.copyWith(
      phases: plan.phases
          .map(
            (phase) => phase.copyWith(
              tasks: phase.tasks
                  .map((t) => t.id == taskId ? updated : t)
                  .toList(growable: false),
            ),
          )
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
