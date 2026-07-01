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
          Icon(Icons.event_outlined, size: 20, color: AppColors.indigo),
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
              onPressed: (adding || onAddToCalendar == null)
                  ? null
                  : onAddToCalendar,
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
