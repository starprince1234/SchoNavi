import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';

/// 「正在思考…」加载气泡：`reasoning.svg` 原子图 + indigo→cyan 渐变填充 +
/// 沿圆周扫过的滑光（SweepGradient，匀速 2s/圈）。文案「正在思考…」同享
/// 渐变填充与横向掠过的亮纹（LinearGradient 平移），与图标视觉语言一致。
/// 纯展示组件，不感知业务状态，不依赖 Riverpod。
///
/// 用于 ChatMessageBubble 思考分支与推荐流程的占位气泡。**不脉动**（无 scale
/// /opacity 动画），只有滑光匀速扫过。
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(); // 单向，不 reverse；匀速扫光
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Stack(
                children: [
                  // 底层：svg 染品牌渐变（indigo→cyan，横向）。
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.brandGradient.createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: SvgPicture.asset(
                      'assets/icons/reasoning.svg',
                      width: 20,
                      height: 20,
                    ),
                  ),
                  // 上层：沿圆周扫过的滑光，匀速旋转。
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      // controller.value ∈ [0,1] → progress ∈ [0, 2π]
                      final progress = _controller.value * 2 * 3.141592653589793;
                      return CustomPaint(
                        size: const Size.square(20),
                        painter: _SweepPainter(progress: progress),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 文案同享渐变填充 + 横向掠过的亮纹，与图标视觉一致。
            // 外层 CustomPaint 的 foregroundPainter 画移动亮带（必须在
            // ShaderMask 之外，否则 srcIn 会把白带也染成品牌渐变）。
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  foregroundPainter: _TextShimmerPainter(
                    progress: _controller.value,
                  ),
                  child: child,
                );
              },
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.brandGradient.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const Text('正在思考…'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 沿圆周扫过的亮带：SweepGradient（透明 → 白 35% → 透明），起点由 [progress]
/// 控制，匀速旋转。叠在 svg 之上，营造「光绕原子图扫过」的效果。
class _SweepPainter extends CustomPainter {
  _SweepPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size.square(s);
    final paint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: progress,
        colors: const [
          Color(0x00FFFFFF), // 透明
          Color(0x59FFFFFF), // 白 35%
          Color(0x00FFFFFF), // 透明
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawCircle(Offset(s / 2, s / 2), s / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _SweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 横向掠过文案的亮带：LinearGradient（透明 → 白 35% → 透明），整体随
/// [progress] 在 [0,1] 内横向平移一个周期。叠在文案之上，营造「光从左掠过
/// 到右」的效果。亮带位于 `ShaderMask` 之外，故 srcIn 不会改其色。
class _TextShimmerPainter extends CustomPainter {
  _TextShimmerPainter({required this.progress});

  /// 0→1 循环；亮带中心从左外侧（-bandWidth/2）平移到右外侧（w+bandWidth/2）。
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 亮带宽度约占文案宽度的 1/3。
    const bandFraction = 1 / 3;
    final bandWidth = w * bandFraction;
    // 中心从 -bandWidth/2（左外）平移到 w + bandWidth/2（右外）。
    final center = -bandWidth / 2 + (w + bandWidth) * progress;
    final rect = Rect.fromCenter(
      center: Offset(center, h / 2),
      width: bandWidth,
      height: h,
    );
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0x00FFFFFF), // 透明
          Color(0x59FFFFFF), // 白 35%
          Color(0x00FFFFFF), // 透明
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _TextShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
