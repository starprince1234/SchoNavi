import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../shared/widgets/bento_tile.dart';

/// 任务清单（spec §7.4）。
///
/// 按阶段分组；每任务一行：checkbox（完成/撤销）+ 标题 + dueDate +
/// 必做/可选/用户 badge + 备注 + 编辑/删除（必做不可删）。每阶段底部
/// 「添加任务」按钮，新增任务 `kind = userAdded`。
class PreparationTaskList extends StatelessWidget {
  const PreparationTaskList({
    super.key,
    required this.plan,
    required this.onToggleTask,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onAddTask,
  });

  final PreparationPlan plan;

  /// 切换任务完成态：参数 (phaseIndex, taskIndex)。调用方负责
  /// toggle `completedAt` 并 `repo.save`。
  final void Function(int phaseIndex, int taskIndex) onToggleTask;

  /// 编辑任务：参数 (phaseIndex, taskIndex)。
  final void Function(int phaseIndex, int taskIndex) onEditTask;

  /// 删除任务：参数 (phaseIndex, taskIndex)。
  final void Function(int phaseIndex, int taskIndex) onDeleteTask;

  /// 添加任务到指定阶段：参数 phaseIndex。
  final void Function(int phaseIndex) onAddTask;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var pi = 0; pi < plan.phases.length; pi++) ...[
          _PhaseHeader(
            title: plan.phases[pi].title,
            taskCount: plan.phases[pi].tasks.length,
          ),
          for (var ti = 0; ti < plan.phases[pi].tasks.length; ti++)
            _TaskTile(
              task: plan.phases[pi].tasks[ti],
              onToggle: () => onToggleTask(pi, ti),
              onEdit: () => onEditTask(pi, ti),
              onDelete: () => onDeleteTask(pi, ti),
            ),
          _AddTaskButton(onTap: () => onAddTask(pi)),
          if (pi != plan.phases.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({required this.title, required this.taskCount});
  final String title;
  final int taskCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 0, 8),
      child: Text(
        '$title · $taskCount 项任务',
	        style: TextStyle(
	          fontSize: 14,
	          fontWeight: FontWeight.w700,
	          color: scheme.onSurface,
	        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final PreparationTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  bool get _deletable =>
      task.kind == PreparationTaskKind.optional ||
      task.kind == PreparationTaskKind.userAdded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BentoTile(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: task.completed,
              onChanged: (_) => onToggle(),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
	                          style: TextStyle(
	                            fontSize: 14,
	                            fontWeight: FontWeight.w600,
	                            color: task.completed
	                                ? AppColors.faintOf(isDark)
	                                : scheme.onSurface,
                            decoration: task.completed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                      _KindBadge(kind: task.kind),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
	                      Icon(
	                        Icons.event_outlined,
	                        size: 13,
	                        color: AppColors.faintOf(isDark),
	                      ),
                      const SizedBox(width: 4),
                      Text(
                        _fmt(task.dueDate),
	                        style: TextStyle(
	                          fontSize: 11,
	                          color: AppColors.faintOf(isDark),
	                        ),
                      ),
                    ],
                  ),
                  if (task.note != null && task.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.note!,
	                      style: TextStyle(
	                        fontSize: 12,
	                        color: scheme.onSurfaceVariant,
	                      ),
                    ),
                  ],
                ],
              ),
            ),
	            IconButton(
	              icon: Icon(
	                Icons.edit_outlined,
	                size: 18,
	                color: AppColors.faintOf(isDark),
	              ),
              tooltip: '编辑',
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
            if (_deletable)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.danger,
                ),
                tooltip: '删除',
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});
  final PreparationTaskKind kind;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (label, fg, bg) = switch (kind) {
      PreparationTaskKind.required => (
        '必做',
        AppColors.danger,
        AppColors.dangerSoftOf(isDark),
      ),
      PreparationTaskKind.optional => (
        '可选',
        AppColors.cyan,
        AppColors.cyanSoftOf(isDark),
      ),
      PreparationTaskKind.userAdded => (
        '用户',
        AppColors.indigo,
        AppColors.indigoSoftOf(isDark),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _AddTaskButton extends StatelessWidget {
  const _AddTaskButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
	          decoration: BoxDecoration(
	            borderRadius: BorderRadius.circular(12),
	            border: Border.all(color: scheme.outline, width: 1),
	          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 16, color: AppColors.indigo),
              SizedBox(width: 6),
              Text(
                '添加任务',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.indigo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
