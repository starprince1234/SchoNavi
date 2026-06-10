import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/recommendation.dart';
import 'field_chips.dart';
import 'match_level_chip.dart';

class ProfessorCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final r = recommendation;
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: AppColors.coral),
            Expanded(
              child: InkWell(
                onTap: onTap,
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
                          if (onFavoritePressed != null) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: isFavorite ? '取消收藏' : '收藏导师',
                              icon: Icon(
                                isFavorite
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                              ),
                              onPressed: () {
                                Haptics.light();
                                onFavoritePressed!();
                              },
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
                      if (onOpenHomepagePressed != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: onOpenHomepagePressed,
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('访问主页'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
