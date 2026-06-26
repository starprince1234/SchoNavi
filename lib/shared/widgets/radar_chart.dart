import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/match_analysis.dart';

/// 契合度雷达：CustomPaint 网格 + 数据多边形，轴标签可点。
class RadarChart extends StatefulWidget {
  const RadarChart({
    super.key,
    required this.dimensions,
    this.onAxisTap,
    this.size = 260,
  });

  final List<MatchDimension> dimensions;
  final void Function(int index)? onAxisTap;
  final double size;

  @override
  State<RadarChart> createState() => _RadarChartState();
}

class _RadarChartState extends State<RadarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = widget.dimensions;
    if (dims.isEmpty) {
      return const SizedBox(width: 1, height: 1, child: CustomPaint());
    }

    final size = widget.size;
    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 34;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _RadarPainter(
                  dimensions: dims,
                  progress: Curves.easeOutCubic.transform(_controller.value),
                  grid: AppColors.line,
                  fill: AppColors.cyan.withValues(alpha: 0.22),
                  stroke: AppColors.cyan,
                ),
              ),
              for (var i = 0; i < dims.length; i++)
                _axisLabel(context, i, center, radius, dims[i]),
            ],
          );
        },
      ),
    );
  }

  Widget _axisLabel(
    BuildContext context,
    int index,
    Offset center,
    double radius,
    MatchDimension dimension,
  ) {
    final angle = -math.pi / 2 + 2 * math.pi * index / widget.dimensions.length;
    final left = center.dx + (radius + 18) * math.cos(angle);
    final top = center.dy + (radius + 18) * math.sin(angle);
    final theme = Theme.of(context);

    return Positioned(
      left: left - 34,
      top: top - 16,
      width: 68,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onAxisTap == null
            ? null
            : () {
                Haptics.selection();
                widget.onAxisTap!(index);
              },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dimension.label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
            Text(
              '${dimension.score}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.cyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.dimensions,
    required this.progress,
    required this.grid,
    required this.fill,
    required this.stroke,
  });

  final List<MatchDimension> dimensions;
  final double progress;
  final Color grid;
  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final count = dimensions.length;
    if (count < 3) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 34;

    Offset vertex(double valueRadius, int index) {
      final angle = -math.pi / 2 + 2 * math.pi * index / count;
      return Offset(
        center.dx + valueRadius * math.cos(angle),
        center.dy + valueRadius * math.sin(angle),
      );
    }

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;

    for (final ring in [1 / 3, 2 / 3, 1.0]) {
      final path = Path();
      for (var i = 0; i < count; i++) {
        final p = vertex(radius * ring, i);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i < count; i++) {
      canvas.drawLine(center, vertex(radius, i), gridPaint);
    }

    final dataPath = Path();
    for (var i = 0; i < count; i++) {
      final valueRadius = radius * (dimensions[i].score / 100) * progress;
      final p = vertex(valueRadius, i);
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(dataPath, Paint()..color = fill);
    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = stroke,
    );

    for (var i = 0; i < count; i++) {
      final valueRadius = radius * (dimensions[i].score / 100) * progress;
      canvas.drawCircle(vertex(valueRadius, i), 3, Paint()..color = stroke);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.dimensions != dimensions ||
      oldDelegate.grid != grid ||
      oldDelegate.fill != fill ||
      oldDelegate.stroke != stroke;
}
