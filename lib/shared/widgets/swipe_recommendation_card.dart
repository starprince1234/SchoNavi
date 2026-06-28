import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/recommendation.dart';
import 'bento_tile.dart';
import 'match_level_chip.dart';

/// 对话流内嵌的浓缩推荐卡（横滑轨道的单张）。
///
/// 沿用 ProfessorCard 的视觉语言（4px 珊瑚左条 + BentoTile + MatchLevelChip），
/// 但去掉 Hero 与「访问主页」独占行，改为底部紧凑的「访问主页 / 收藏」按钮行，
/// 高度可控以适配 PageView 的固定高度。点击卡片整体触发 [onTap] 进导师详情。
class SwipeRecommendationCard extends StatefulWidget {
  const SwipeRecommendationCard({
    super.key,
    required this.recommendation,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoritePressed,
    this.onOpenHomepagePressed,
  });

  final Recommendation recommendation;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onOpenHomepagePressed;

  @override
  State<SwipeRecommendationCard> createState() =>
      _SwipeRecommendationCardState();
}

class _SwipeRecommendationCardState extends State<SwipeRecommendationCard> {
  bool _favoriteDown = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.recommendation;
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final card = BentoTile(
          onTap: widget.onTap,
          padding: EdgeInsets.zero,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: AppColors.indigo),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                // 职称弱化为 labelSmall，与姓名形成「重—弱」节奏。
                                Text(
                                  r.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.inkFaint,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // 学校行提级：indigo 图标 + 单行，形成「中」档视觉锚点。
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.school_outlined,
                                      size: 13,
                                      color: AppColors.indigo,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${r.university} / ${r.college}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          MatchLevelChip(
                            level: r.matchLevel,
                            matchScore: r.matchScore,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _CompactFields(fields: r.researchFields),
                      const SizedBox(height: 8),
                      // 推荐理由引述化：cyan 竖条锚点。
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 3,
                              margin: const EdgeInsets.only(right: 8, top: 2),
                              decoration: BoxDecoration(
                                color: AppColors.cyan,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                r.reason,
                                style: theme.textTheme.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (widget.onOpenHomepagePressed != null ||
                          widget.onFavoritePressed != null)
                        Row(
                          children: [
                            if (widget.onOpenHomepagePressed != null)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                  foregroundColor: AppColors.cyan,
                                  iconColor: AppColors.cyan,
                                ),
                                onPressed: () {
                                  Haptics.light();
                                  widget.onOpenHomepagePressed!();
                                },
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('访问主页'),
                              ),
                            const Spacer(),
                            if (widget.onFavoritePressed != null)
                              Listener(
                                onPointerDown: (_) =>
                                    setState(() => _favoriteDown = true),
                                onPointerUp: (_) =>
                                    setState(() => _favoriteDown = false),
                                onPointerCancel: (_) =>
                                    setState(() => _favoriteDown = false),
                                child: AnimatedScale(
                                  scale: _favoriteDown ? 0.85 : 1.0,
                                  duration: const Duration(milliseconds: 120),
                                  // 按下态 + 已收藏态：indigoSoft 背景晕；已收藏追加 glow 外发光。
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 150),
                                    decoration: BoxDecoration(
                                      color: (_favoriteDown ||
                                              widget.isFavorite)
                                          ? AppColors.indigoSoft
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: widget.isFavorite
                                          ? const [AppColors.shadowGlow]
                                          : null,
                                    ),
                                    child: IconButton(
                                      constraints: const BoxConstraints(
                                        minWidth: 44,
                                        minHeight: 44,
                                      ),
                                      tooltip: widget.isFavorite
                                          ? '取消收藏'
                                          : '收藏导师',
                                      icon: Icon(
                                        widget.isFavorite
                                            ? Icons.bookmark
                                            : Icons.bookmark_border,
                                        color: widget.isFavorite
                                            ? AppColors.indigo
                                            : null,
                                      ),
                                      onPressed: () {
                                        Haptics.light();
                                        widget.onFavoritePressed!();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
        if (constraints.hasBoundedHeight) return card;
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        return SizedBox(
          height: 250 + (textScale - 1).clamp(0, 1) * 54,
          child: card,
        );
      },
    );
  }
}

class _CompactFields extends StatelessWidget {
  const _CompactFields({required this.fields});

  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) {
      return Text('暂无方向信息', style: Theme.of(context).textTheme.bodySmall);
    }
    final visible = fields.take(2).toList(growable: false);
    final hidden = fields.length - visible.length;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final field in visible)
          Container(
            constraints: const BoxConstraints(maxWidth: 118),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.indigoSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              field,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.indigoPressed,
              ),
            ),
          ),
        if (hidden > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cyanSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '+$hidden',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.cyan,
              ),
            ),
          ),
      ],
    );
  }
}
