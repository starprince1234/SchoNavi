import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/match_level.dart';

/// 匹配度胶囊：高=indigo 实心（最强），中=cyan soft（次），低=冷灰（弱）。
/// 冷调语义梯度，颜色非唯一指示——文字始终标注「匹配度」。
///
/// 当 [matchScore] 非 null 时（0.0–1.0），胶囊左侧追加 mini 进度弧 + 百分比，
/// 强化数据感；为 null 时退化为纯文字药丸「匹配度：高/中/低」。
class MatchLevelChip extends StatelessWidget {
  const MatchLevelChip({super.key, required this.level, this.matchScore});

  final MatchLevel level;

  /// 可选匹配分（0.0–1.0）。提供时渲染进度弧与百分比，否则纯文字。
  final double? matchScore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final (Color bg, Color fg) = switch (level) {
      MatchLevel.high => (AppColors.indigo, Colors.white),
      MatchLevel.medium => (
        AppColors.indigoSoftOf(isDark),
        isDark ? AppColors.inkDark : AppColors.indigoPressed,
      ),
      MatchLevel.low => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

    if (matchScore == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '匹配度：${level.label}',
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    final pct = '${(matchScore! * 100).round()}%';
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CustomPaint(
              size: const Size.square(18),
              painter: _MatchRingPainter(
                progress: matchScore!,
                trackColor: fg.withValues(alpha: 0.35),
                fillColor: fg,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            pct,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// mini 进度弧：背景圆环（track）+ 前景圆弧（fill），顺时针从顶部生长。
/// [progress] 0.0–1.0 映射到 0°–360°。
class _MatchRingPainter extends CustomPainter {
  const _MatchRingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  final double progress;
  final Color trackColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 7.0;
    const strokeWidth = 2.5;
    // 进度弧起点定在顶部（-π/2），顺时针。
    final startAngle = -math.pi / 2;
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MatchRingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor;
}
