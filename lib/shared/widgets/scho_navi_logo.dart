import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// SchoNavi 品牌矢量标（依赖无关，CustomPaint 等价 SVG，任意密度清晰）。
///
/// 沿用 favicon 的「圆角方 + 帆/叶 + 航向横线」语义（学校 + 导航），重染冷调：
/// 深 slate→indigo 渐变底，cyan 帆叶，白航向线。可选 [withWordmark] 在右侧
/// 附带「SchoNavi」字标（indigo→cyan 渐变）。尺寸由 [size] 控制图标直径。
class SchoNaviLogo extends StatelessWidget {
  const SchoNaviLogo({
    super.key,
    this.size = 40,
    this.withWordmark = false,
    this.wordmarkStyle,
  });

  final double size;

  /// 是否附带文字标。
  final bool withWordmark;

  /// 文字标样式；默认取 headlineMedium 并注入品牌渐变。
  final TextStyle? wordmarkStyle;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(size: Size.square(size), painter: _MarkPainter()),
    );

    if (!withWordmark) return mark;

    final style =
        (wordmarkStyle ??
                Theme.of(context).textTheme.headlineMedium ??
                const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))
            .copyWith(fontWeight: FontWeight.w800);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.18),
        ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.brandGradient.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            'SchoNavi',
            style: style.copyWith(color: AppColors.indigo),
          ),
        ),
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = s * 0.188; // 圆角 ≈ 12/64

    // 底：slate-900 → indigo 深渐变圆角方。
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

    // 帆/叶：cyan 实心，从左下向右上扬起（导航/成长语义）。
    final leaf = Path()
      ..moveTo(s * 0.25, s * 0.61)
      ..cubicTo(s * 0.36, s * 0.34, s * 0.50, s * 0.22, s * 0.75, s * 0.23)
      ..cubicTo(s * 0.67, s * 0.47, s * 0.53, s * 0.61, s * 0.25, s * 0.61)
      ..close();
    canvas.drawPath(leaf, Paint()..color = AppColors.cyanBright);

    // 航向横线：白，圆头描边。
    canvas.drawLine(
      Offset(s * 0.31, s * 0.70),
      Offset(s * 0.69, s * 0.70),
      Paint()
        ..color = Colors.white
        ..strokeWidth = s * 0.078
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
