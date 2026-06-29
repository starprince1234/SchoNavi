import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/plan_change_card.dart';
import '../../../shared/widgets/bento_tile.dart';

/// 只读改动卡视图（spec §2.6 / P4a.5）：展示 [PlanChangeCard.summary] +
/// [PlanChangeCard.rationale] + 状态胶囊；rejected 时附带 reason。
///
/// 本任务仅渲染，不绑定接受/拒绝（P4b.2 接入）；接受按钮以禁用占位呈现，
/// 表明交互入口已就位但尚未开放。
class PlanChangeCardView extends StatelessWidget {
  const PlanChangeCardView({super.key, required this.card});

  final PlanChangeCard card;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusStyle = _statusStyle(card.status, scheme);
    return BentoTile(
      width: 280,
      color: scheme.surface,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_typeIcon(card.type), size: 18, color: AppColors.indigo),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  card.summary,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            card.rationale,
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusChip(label: statusStyle.label, color: statusStyle.color),
              if (card.status == ChangeCardStatus.rejected &&
                  card.rejectionReason != null)
                Text(
                  card.rejectionReason!,
                  style: TextStyle(fontSize: 12, color: AppColors.danger),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: null,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.surfaceContainerHighest,
                foregroundColor: AppColors.inkSoft,
              ),
              child: const Text('接受', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(ChangeCardType t) => switch (t) {
        ChangeCardType.moveTask => Icons.drag_handle_rounded,
        ChangeCardType.addTask => Icons.add_task_rounded,
        ChangeCardType.deleteTask => Icons.delete_outline,
        ChangeCardType.reschedulePhase => Icons.event_repeat_outlined,
        ChangeCardType.appendAdvice => Icons.lightbulb_outline,
      };

  ({String label, Color color}) _statusStyle(
    ChangeCardStatus s,
    ColorScheme scheme,
  ) => switch (s) {
        ChangeCardStatus.pending => (label: '待确认', color: AppColors.indigo),
        ChangeCardStatus.rejected => (label: '已驳回', color: AppColors.danger),
        ChangeCardStatus.applied => (label: '已应用', color: AppColors.match),
        ChangeCardStatus.declined => (label: '已忽略', color: AppColors.inkFaint),
        ChangeCardStatus.stale => (label: '已过期', color: AppColors.inkFaint),
      };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
