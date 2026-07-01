import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 毛玻璃面：统一的冷调 frosted-glass 容器。
///
/// 把 `BackdropFilter` 模糊 + 半透明底 + 玻璃高光描边 + 冷阴影收敛到一处，
/// 全 App 的卡片/输入条/抽屉/弹层共用同一视觉语言。当 [frosted] 为 false
/// 时退化为实心冷面（用于长列表卡片，保证密集文本可读性与性能）。
///
/// 性能注意：[BackdropFilter] 会触发每帧离屏光栅化，长列表中大量使用会拖慢
/// 滚动。滚动列表内的条目请用 `frosted: false`，仅固定/浮层用 `frosted: true`。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.frosted = true,
    this.radius = 18,
    this.padding,
    this.border,
    this.shadow = AppColors.shadowCool,
    this.gradient,
    this.blendMode,
  });

  final Widget child;

  /// 是否启用毛玻璃模糊。长列表条目置 false。
  final bool frosted;

  final double radius;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;
  final BoxShadow? shadow;
  final Gradient? gradient;

  /// 模糊层与底色叠加模式，默认 srcOver（底色在上，模糊在下补内容）。
  final BlendMode? blendMode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = gradient == null ? AppColors.glassOf(isDark) : null;

    final decoration = BoxDecoration(
      color: gradient == null ? baseColor : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: AppColors.glassBorderOf(isDark)),
      boxShadow: shadow != null ? [shadow!] : null,
    );

    Widget content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    if (!frosted) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    // 玻璃面：底层模糊内容 → 叠半透明底 + 描边 + 阴影 → 顶部 1px 高光。
    // 用 ClipRRect 按圆角裁剪整个 Stack，否则 BackdropFilter 的模糊层会以
    // 矩形溢出圆角外（DecoratedBox 自身不裁剪），圆形按钮不 hover 时
    // 露出矩形模糊边。radius 与 decoration.borderRadius 一致。
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: AppColors.glassBlur,
                  sigmaY: AppColors.glassBlur,
                ),
                blendMode: blendMode ?? BlendMode.srcOver,
                child: const SizedBox.expand(),
              ),
            ),
            // 顶部高光：一条 1px 渐隐白线，模拟环境光折射边。
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.glassHighlight.withValues(alpha: 0),
                      AppColors.glassHighlight,
                      AppColors.glassHighlight.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radius),
                  ),
                ),
              ),
            ),
            content,
          ],
        ),
      ),
    );
  }
}
