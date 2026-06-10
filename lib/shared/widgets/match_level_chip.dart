import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/match_level.dart';

class MatchLevelChip extends StatelessWidget {
  const MatchLevelChip({super.key, required this.level});

  final MatchLevel level;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (level) {
      MatchLevel.high => (AppColors.ink, AppColors.paper),
      MatchLevel.medium => (AppColors.coralSoft, AppColors.coral),
      MatchLevel.low => (AppColors.panel, AppColors.inkSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '匹配度：${level.label}',
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}
