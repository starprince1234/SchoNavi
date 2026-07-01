import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../shared/widgets/bento_tile.dart';

/// 备赛计划列表行（spec §7.4 列表）。
///
/// BentoTile 风格（圆角描边、按下反馈）；展示赛事名 + 剩余天数 + 完成度。
/// 剩余天数 = `max(0, targetDate.difference(today).inDays)`；
/// 完成度 = 已完成任务数 / 总任务数。
class PreparationPlanListTile extends StatelessWidget {
  const PreparationPlanListTile({
    super.key,
    required this.plan,
    required this.onTap,
  });

  final PreparationPlan plan;
  final VoidCallback onTap;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int get _daysLeft {
    final target = DateTime(
      plan.targetDate.year,
      plan.targetDate.month,
      plan.targetDate.day,
    );
    final diff = target.difference(_today).inDays;
    return diff < 0 ? 0 : diff;
  }

  (int completed, int total) get _progress {
    var completed = 0;
    var total = 0;
    for (final phase in plan.phases) {
      for (final task in phase.tasks) {
        total++;
        if (task.completed) completed++;
      }
    }
    return (completed, total);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (completed, total) = _progress;
    final ratio = total == 0 ? 0.0 : completed / total;
    final daysLeft = _daysLeft;

    return BentoTile(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      border: Border.fromBorderSide(
        BorderSide(color: AppColors.lineOf(isDark), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  plan.competition.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkOf(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _DaysChip(daysLeft: daysLeft, isDark: isDark),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.panelOf(isDark),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyan),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$completed/$total 已完成',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.inkSoftOf(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysChip extends StatelessWidget {
  const _DaysChip({required this.daysLeft, required this.isDark});

  final int daysLeft;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final urgent = daysLeft <= 7;
    final bg = urgent
        ? AppColors.dangerSoftOf(isDark)
        : AppColors.cyanSoftOf(isDark);
    final fg = urgent ? AppColors.danger : AppColors.cyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        daysLeft == 0 ? '今日' : '$daysLeft天',
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
