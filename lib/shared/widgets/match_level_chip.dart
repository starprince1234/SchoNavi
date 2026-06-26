import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/match_level.dart';

/// 匹配度胶囊：高=indigo 实心（最强），中=cyan soft（次），低=冷灰（弱）。
/// 冷调语义梯度，颜色非唯一指示——文字始终标注「匹配度」。
class MatchLevelChip extends StatelessWidget {
  const MatchLevelChip({super.key, required this.level});

  final MatchLevel level;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (level) {
      MatchLevel.high => (AppColors.indigo, Colors.white),
      MatchLevel.medium => (AppColors.indigoSoft, AppColors.indigoPressed),
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
