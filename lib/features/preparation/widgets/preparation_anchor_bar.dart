import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/preparation_plan.dart';

/// 备赛锚点条（spec §4.5 / §7.4）：在详情页倒计时下方展示赛事时间锚点。
///
/// - 窗口型：`比赛 M/D–M/D`（eventEndDate 缺省或等于 targetDate 时退化为单日）。
/// - 提交型：`提交 DDL M/D · 答辩 M/D`（无 defenseDate 时省略答辩段）。
class PreparationAnchorBar extends StatelessWidget {
  const PreparationAnchorBar({super.key, required this.plan});

  final PreparationPlan plan;

  static String _md(DateTime d) => '${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    final isWindow = plan.timelineType == CompetitionTimelineType.eventWindow;
    final String label;
    if (isWindow) {
      final end = plan.eventEndDate;
      if (end == null ||
          end.year == plan.targetDate.year &&
              end.month == plan.targetDate.month &&
              end.day == plan.targetDate.day) {
        label = '比赛 ${_md(plan.targetDate)}';
      } else {
        label = '比赛 ${_md(plan.targetDate)}–${_md(end)}';
      }
    } else {
      final buf = StringBuffer('提交 DDL ${_md(plan.targetDate)}');
      final defense = plan.defenseDate;
      if (defense != null) {
        buf.write(' · 答辩 ${_md(defense)}');
      }
      label = buf.toString();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.indigoSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 16,
            color: AppColors.indigo,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.indigo,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
