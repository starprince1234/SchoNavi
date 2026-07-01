import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/calendar_date.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../shared/widgets/bento_tile.dart';
import '../../../shared/widgets/empty_view.dart';
import '../providers/preparation_providers.dart';

class TodayTasksPage extends ConsumerWidget {
  const TodayTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final asyncList = ref.watch(preparationPlanListProvider);

    return Scaffold(
      backgroundColor: AppColors.paperOf(isDark),
      appBar: AppBar(
        title: const Text('今日任务'),
        backgroundColor: AppColors.paperOf(isDark),
        elevation: 0,
        foregroundColor: AppColors.inkOf(isDark),
      ),
      body: asyncList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyView(message: '今日任务加载失败：$e'),
        data: (plans) {
          final tasks = _todayTasks(plans);
          if (tasks.isEmpty) {
            return EmptyView(
              message: '今天暂无待完成任务',
              actionLabel: '查看备赛计划',
              onAction: () => context.go('/preparation-plans'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _TodayTaskTile(
                item: tasks[index],
                onTap: () =>
                    context.push('/preparation-plans/${tasks[index].plan.id}'),
              );
            },
          );
        },
      ),
    );
  }

  List<_TodayTaskItem> _todayTasks(List<PreparationPlan> plans) {
    final today = CalendarDate.normalize(DateTime.now());
    final items = <_TodayTaskItem>[];
    for (final plan in plans) {
      if (plan.status != PreparationPlanStatus.active) continue;
      for (final phase in plan.phases) {
        for (final task in phase.tasks) {
          if (task.completed) continue;
          if (CalendarDate.normalize(task.dueDate) != today) continue;
          items.add(_TodayTaskItem(plan: plan, phase: phase, task: task));
        }
      }
    }
    items.sort((a, b) {
      final planOrder = b.plan.updatedAt.compareTo(a.plan.updatedAt);
      if (planOrder != 0) return planOrder;
      return a.task.title.compareTo(b.task.title);
    });
    return items;
  }
}

class _TodayTaskItem {
  const _TodayTaskItem({
    required this.plan,
    required this.phase,
    required this.task,
  });

  final PreparationPlan plan;
  final PreparationPhase phase;
  final PreparationTask task;
}

class _TodayTaskTile extends StatelessWidget {
  const _TodayTaskTile({required this.item, required this.onTap});

  final _TodayTaskItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BentoTile(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      borderRadius: 16,
      border: Border.fromBorderSide(
        BorderSide(color: AppColors.lineOf(isDark), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.today_outlined,
              size: 20,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.task.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.inkOf(isDark),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.plan.competition.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoftOf(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      size: 14,
                      color: AppColors.inkFaint,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.phase.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}
