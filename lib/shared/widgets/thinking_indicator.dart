import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 「正在思考…」加载气泡：CustomPaint 手绘大脑（indigo→cyan 渐变）+
/// scale/opacity 呼吸动画。纯展示组件，不感知业务状态，不依赖 Riverpod。
///
/// 沿用项目矢量风格（CustomPaint 等价 SVG，依赖无关），与 scho_navi_logo、
/// radar_chart 一致。用于 ChatMessageBubble 思考分支与推荐流程的占位气泡。
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 0.92, end: 1.08).animate(curve);
    _opacity = Tween<double>(begin: 0.55, end: 1.0).animate(curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Opacity(
              opacity: _opacity.value,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: _scale.value,
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CustomPaint(
                        size: Size.square(18),
                        painter: _BrainPainter(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('正在思考…'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 大脑俯视剪影：两半球 + 沟回暗纹 + 顶部高光，indigo→cyan 渐变填充。
/// shouldRepaint = false：笔触静态，脉动靠外层 Transform.scale / Opacity。
class _BrainPainter extends CustomPainter {
  const _BrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size.square(s);

    // 大脑 Path：两半球俯视剪影，中线 0.50，顶部 0.18，底部 0.82。
    final brain = Path()
      ..moveTo(s * 0.50, s * 0.18)
      // 右半球：顶 → 右下 → 底中
      ..cubicTo(s * 0.86, s * 0.20, s * 0.92, s * 0.58, s * 0.74, s * 0.82)
      ..cubicTo(s * 0.62, s * 0.88, s * 0.54, s * 0.80, s * 0.50, s * 0.78)
      // 左半球：底中 → 左下 → 顶（闭合）
      ..cubicTo(s * 0.46, s * 0.80, s * 0.38, s * 0.88, s * 0.26, s * 0.82)
      ..cubicTo(s * 0.08, s * 0.58, s * 0.14, s * 0.20, s * 0.50, s * 0.18)
      ..close();

    // 渐变填充：indigo → cyan（横向）。
    final fill = Paint()
      ..shader = AppColors.brandGradient.createShader(rect);
    canvas.drawPath(brain, fill);

    // 沟回暗纹：两半球各一道浅沟，白色 35% 描边。
    final sulci = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;
    final leftSulcus = Path()
      ..moveTo(s * 0.40, s * 0.30)
      ..quadraticBezierTo(s * 0.30, s * 0.48, s * 0.36, s * 0.66);
    final rightSulcus = Path()
      ..moveTo(s * 0.60, s * 0.30)
      ..quadraticBezierTo(s * 0.70, s * 0.48, s * 0.64, s * 0.66);
    canvas.drawPath(leftSulcus, sulci);
    canvas.drawPath(rightSulcus, sulci);

    // 顶部高光：白色 18% 弧，模拟环境光折射。
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.30),
        width: s * 0.50,
        height: s * 0.30,
      ),
      3.6,
      1.9,
      false,
      highlight,
    );
  }

  @override
  bool shouldRepaint(covariant _BrainPainter oldDelegate) => false;
}
