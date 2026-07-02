import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';

/// 「正在思考」加载气泡：`reasoning.svg` 原子图 + indigo→cyan 渐变填充 +
/// 沿圆周扫过的滑光（SweepGradient，匀速 2s/圈）。文案「正在思考」同享
/// 渐变填充与横向掠过的亮纹（LinearGradient 平移），与图标视觉语言一致。
/// 尾部三个独立方形点（句号样式）用品牌渐变填充并错峰上下跳跃（波浪式），
/// 贴在文案底部对齐，暗示「思考中」。纯展示组件，不感知业务状态，不依赖 Riverpod。
///
/// 用于 ChatMessageBubble 思考分支与推荐流程的占位气泡。
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key});

  /// 扫光亮带峰值色（透明 → 峰值 → 透明 的中段），按明度自适应：
  /// 浅色 35% 白、深色 22% 白。色相一致仅明度切换，与 [AppColors] 设计基线一致。
  /// 深色下调低高光强度，避免在 indigo→cyan 渐变填充上过刺眼。
  @visibleForTesting
  static Color shimmerPeakColorFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return Color(isDark ? 0x38FFFFFF : 0x59FFFFFF); // 深 22% / 浅 35%
  }

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

  /// 第 i 个点的纵向偏移（px，向上为负）。由 `_controller.value`（记为 v）
  /// 派生：2s controller 内每点跑 2 个周期（每秒约 1 跳），三点错峰 0.2 形
  /// 成波浪；每周期 60% 活跃（sin 半波）、40% 静止。幅度 3px（点本身 3×3，
  /// 跳跃幅度与点等宽，克制）。
  double _dotOffset(int i) {
    final v = _controller.value;
    final t = (v * 2 + i * 0.2) % 1.0;
    if (t > 0.6) return 0.0;
    final u = t / 0.6;
    return -math.sin(u * math.pi) * 3;
  }

  @override
  Widget build(BuildContext context) {
    final peakColor = ThinkingIndicator.shimmerPeakColorFor(
      Theme.of(context).brightness,
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
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
                      final progress =
                          _controller.value * 2 * 3.141592653589793;
                      return CustomPaint(
                        size: const Size.square(20),
                        painter: _SweepPainter(
                          progress: progress,
                          peakColor: peakColor,
                        ),
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
                    peakColor: peakColor,
                  ),
                  child: child,
                );
              },
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.brandGradient.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const Text('正在思考'),
              ),
            ),
            const SizedBox(width: 3),
            // 尾三方形点（句号样式）：品牌渐变填充，错峰上下跳跃（波浪式）。
            // 仅 translate，不改布局、无 scale/opacity。贴文案底部对齐。
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
                        child: Transform.translate(
                          offset: Offset(0, _dotOffset(i)),
                          child: SizedBox(
                            key: ValueKey<int>(i),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                shape: BoxShape.rectangle,
                              ),
                              child: SizedBox(width: 3, height: 3),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 沿圆周扫过的亮带：SweepGradient（透明 → 峰值 → 透明），起点由 [progress]
/// 控制，匀速旋转。叠在 svg 之上，营造「光绕原子图扫过」的效果。峰值色由
/// [peakColor] 传入，按明暗自适应（见 [ThinkingIndicator.shimmerPeakColorFor]）。
class _SweepPainter extends CustomPainter {
  _SweepPainter({required this.progress, required this.peakColor});

  final double progress;
  final Color peakColor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size.square(s);
    final paint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: progress,
        colors: [
          const Color(0x00FFFFFF), // 透明
          peakColor,
          const Color(0x00FFFFFF), // 透明
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawCircle(Offset(s / 2, s / 2), s / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _SweepPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.peakColor != peakColor;
}

/// 横向掠过文案的亮带：LinearGradient（透明 → 峰值 → 透明），整体随
/// [progress] 在 [0,1] 内横向平移一个周期。叠在文案之上，营造「光从左掠过
/// 到右」的效果。亮带位于 `ShaderMask` 之外，故 srcIn 不会改其色。峰值色由
/// [peakColor] 传入，按明暗自适应（见 [ThinkingIndicator.shimmerPeakColorFor]）。
class _TextShimmerPainter extends CustomPainter {
  _TextShimmerPainter({required this.progress, required this.peakColor});

  /// 0→1 循环；亮带中心从左外侧（-bandWidth/2）平移到右外侧（w+bandWidth/2）。
  final double progress;
  final Color peakColor;

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
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0x00FFFFFF), // 透明
          peakColor,
          const Color(0x00FFFFFF), // 透明
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _TextShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.peakColor != peakColor;
}
