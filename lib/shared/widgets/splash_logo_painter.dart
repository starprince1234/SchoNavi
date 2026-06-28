import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 把 [t] 在 [a]-[b] 区间内归一化到 0.0-1.0，区间外 clamp。
double clampInterval(double t, double a, double b) {
  if (b <= a) return t <= a ? 0.0 : 1.0;
  return ((t - a) / (b - a)).clamp(0.0, 1.0);
}

/// progress 驱动的 SchoNavi 品牌标 CustomPainter。
///
/// 三段错峰绘制（progress 0→1，总时长 2.0s）：
/// - 圆角方底（slate→indigo 渐变）：[0.0, 0.28] opacity 0→1 + scale 0.7→1.0。
/// - cyan 帆叶：[0.18, 0.68] 沿贝塞尔曲线 trim 生长（PathMetric.extractPath）。
/// - 白航向线：[0.58, 0.88] 从左到右横向画出（圆头描边）。
///
/// 节奏在 1.8s→2.0s 延长后重平衡：帆叶区间略前置、收尾留白收窄，避免生长仓促。
/// 绘制语义沿用 [SchoNaviLogo._MarkPainter]：圆角方 + 帆叶（学校+导航/成长）+
/// 白航向线。progress=0 时不绘制帆叶与航向线。
class SplashLogoPainter extends CustomPainter {
  SplashLogoPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = s * 0.188;

    // ── 圆角方底：opacity + scale ──
    // 注意：Paint 同时设 shader 与 color 时 color/alpha 被忽略，故用 saveLayer
    // 的 alpha 控制整体透明度（先 save+saveLayer 限定范围 → scale → drawRRect）。
    final bgT = clampInterval(progress, 0.0, 0.28);
    if (bgT > 0) {
      final scale = 0.7 + 0.3 * bgT; // 0.7→1.0
      canvas.save();
      canvas.translate(s / 2, s / 2);
      canvas.scale(scale);
      canvas.translate(-s / 2, -s / 2);
      // saveLayer alpha 控制透明度（shader 上的 color alpha 无效）。
      final layerPaint = Paint()..color = Color.fromRGBO(0, 0, 0, bgT);
      canvas.saveLayer(Offset.zero & size, layerPaint);
      final bgPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF312E81)],
        ).createShader(Offset.zero & size);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)),
        bgPaint,
      );
      canvas.restore();
      canvas.restore();
    }

    // ── 帆叶：沿贝塞尔 trim 生长 ──
    final leafT = clampInterval(progress, 0.18, 0.68);
    if (leafT > 0) {
      final fullLeaf = Path()
        ..moveTo(s * 0.25, s * 0.61)
        ..cubicTo(s * 0.36, s * 0.34, s * 0.50, s * 0.22, s * 0.75, s * 0.23)
        ..cubicTo(s * 0.67, s * 0.47, s * 0.53, s * 0.61, s * 0.25, s * 0.61)
        ..close();
      final metrics = fullLeaf.computeMetrics();
      final subPath = Path();
      for (final m in metrics) {
        subPath.addPath(m.extractPath(0, m.length * leafT), Offset.zero);
      }
      canvas.drawPath(subPath, Paint()..color = AppColors.cyanBright);
    }

    // ── 航向线：从左到右画出 ──
    final lineT = clampInterval(progress, 0.58, 0.88);
    if (lineT > 0) {
      final startX = s * 0.31;
      final fullEndX = s * 0.69;
      final endX = startX + (fullEndX - startX) * lineT;
      canvas.drawLine(
        Offset(startX, s * 0.70),
        Offset(endX, s * 0.70),
        Paint()
          ..color = Colors.white
          ..strokeWidth = s * 0.078
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SplashLogoPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
