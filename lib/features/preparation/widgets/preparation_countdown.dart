import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../shared/widgets/bento_tile.dart';

/// 备赛倒计时卡片（spec §7.4）。
///
/// 三段信息：
/// - 剩余天数 = `targetDate - today`（≥0）。
/// - 总进度 = 已完成任务数 / 总任务数 + 进度条。
/// - 当前阶段 = today 落在哪个阶段。
///
/// `tightSchedule`/`overload` 为 true 时顶部叠一条警示横幅。
class PreparationCountdown extends StatelessWidget {
  const PreparationCountdown({
    super.key,
    required this.plan,
    required this.today,
  });

  final PreparationPlan plan;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final remaining = plan.targetDate.difference(today).inDays;
    final remainingClamped = remaining < 0 ? 0 : remaining;

    final allTasks = plan.phases.expand((p) => p.tasks).toList();
    final total = allTasks.length;
    final completed = allTasks.where((t) => t.completed).length;
    final progress = total == 0 ? 0.0 : completed / total;

    final currentPhase = _currentPhase();

    return BentoTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.tightSchedule || plan.overload) ...[
            _warningBanner(),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$remainingClamped',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppColors.indigo,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  '剩余天数',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                ),
              ),
              const Spacer(),
              Text(
                '$completed/$total',
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.line,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyan),
            ),
          ),
          const SizedBox(height: 10),
          if (currentPhase != null)
            Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  size: 16,
                  color: AppColors.cyan,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '当前阶段：${currentPhase.title}',
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            )
          else
            const Text(
              '当前阶段：—',
              style: TextStyle(color: AppColors.inkFaint, fontSize: 12),
            ),
        ],
      ),
    );
  }

  PreparationPhase? _currentPhase() {
    for (final phase in plan.phases) {
      if (!today.isBefore(phase.startDate) && !today.isAfter(phase.endDate)) {
        return phase;
      }
    }
    return null;
  }

  Widget _warningBanner() {
    final isOverload = plan.overload;
    final label = isOverload ? '任务超负荷，建议精简' : '时间偏紧，请抓紧节奏';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppColors.danger,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.danger,
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
