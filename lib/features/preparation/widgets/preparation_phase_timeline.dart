import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../shared/widgets/bento_tile.dart';

/// 阶段时间轴（spec §7.4）。
///
/// 每阶段一行：序号节点 + 标题 + 日期区间 + 进度（已完成/总）。
/// today 落在的阶段高亮（indigo 节点 + 浅 indigo 底纹）。
class PreparationPhaseTimeline extends StatelessWidget {
  const PreparationPhaseTimeline({
    super.key,
    required this.plan,
    required this.today,
  });

  final PreparationPlan plan;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return BentoTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '阶段时间轴',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < plan.phases.length; i++)
            _PhaseRow(
              phase: plan.phases[i],
              index: i,
              isCurrent: _isCurrent(plan.phases[i]),
              isLast: i == plan.phases.length - 1,
            ),
        ],
      ),
    );
  }

  bool _isCurrent(PreparationPhase phase) =>
      !today.isBefore(phase.startDate) && !today.isAfter(phase.endDate);
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({
    required this.phase,
    required this.index,
    required this.isCurrent,
    required this.isLast,
  });

  final PreparationPhase phase;
  final int index;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final total = phase.tasks.length;
    final completed = phase.tasks.where((t) => t.completed).length;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent ? AppColors.indigo : AppColors.line,
                    border: isCurrent
                        ? null
                        : Border.all(color: AppColors.inkFaint, width: 1.5),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: AppColors.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: isCurrent
                    ? BoxDecoration(
                        color: AppColors.indigoSoft,
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            phase.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isCurrent
                                  ? AppColors.indigo
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          '$completed/$total',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmt(phase.startDate)} → ${_fmt(phase.endDate)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
