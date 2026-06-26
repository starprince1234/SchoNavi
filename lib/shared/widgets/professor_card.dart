import 'package:flutter/material.dart';
import '../../core/haptics/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/recommendation.dart';
import 'bento_tile.dart';
import 'field_chips.dart';
import 'match_level_chip.dart';

class ProfessorCard extends StatefulWidget {
  const ProfessorCard({
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
  State<ProfessorCard> createState() => _ProfessorCardState();
}

class _ProfessorCardState extends State<ProfessorCard> {
  bool _favoriteDown = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.recommendation;
    final theme = Theme.of(context);
    return BentoTile(
      onTap: widget.onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: AppColors.indigo),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
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
                              Hero(
                                tag: 'prof-name-${r.professorId}',
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: Text(
                                    r.name,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(r.title, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        MatchLevelChip(level: r.matchLevel),
                        if (widget.onFavoritePressed != null) ...[
                          const SizedBox(width: 4),
                          Listener(
                            onPointerDown: (_) => setState(() => _favoriteDown = true),
                            onPointerUp: (_) => setState(() => _favoriteDown = false),
                            onPointerCancel: (_) => setState(() => _favoriteDown = false),
                            child: AnimatedScale(
                              scale: _favoriteDown ? 0.85 : 1.0,
                              duration: const Duration(milliseconds: 120),
                              child: IconButton(
                                tooltip: widget.isFavorite ? '取消收藏' : '收藏导师',
                                icon: Icon(
                                  widget.isFavorite
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                ),
                                onPressed: () {
                                  Haptics.light();
                                  widget.onFavoritePressed!();
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.university} / ${r.college}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    FieldChips(fields: r.researchFields),
                    const SizedBox(height: 10),
                    Text(
                      '推荐理由：${r.reason}',
                      style: theme.textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.onOpenHomepagePressed != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: widget.onOpenHomepagePressed,
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('访问主页'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
