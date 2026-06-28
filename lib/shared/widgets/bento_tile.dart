import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_colors.dart';
import 'glass_surface.dart';

/// Bento tile with press feedback and optional tap behavior.
///
/// When [onTap] is provided, the gesture area is constrained to a minimum
/// of 48x48 logical pixels to meet accessibility tap-target guidelines.
///
/// 冷调玻璃拟态：默认实心冷面（长列表友好、性能优），[frosted] 开启毛玻璃
/// （用于浮层/输入条/hero 等固定区）。按下态用浅冷叠层而非纯黑；调用方可通过
/// [border] 提供与圆角轮廓一致的主题描边。
class BentoTile extends StatefulWidget {
  const BentoTile({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.padding = const EdgeInsets.all(14),
    this.border,
    this.shadow = AppColors.shadowCool,
    this.gradient,
    this.borderRadius = 18,
    this.height,
    this.width,
    this.haptic,
    this.frosted = false,
    this.minTapTarget = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final BoxBorder? border;

  /// Elevation-like shadow. Set to `null` to remove.
  final BoxShadow? shadow;

  /// Optional background gradient. When set, [color] is ignored.
  final Gradient? gradient;

  /// Corner radius of the tile.
  final double borderRadius;

  /// Optional fixed height.
  final double? height;

  /// Optional fixed width.
  final double? width;

  /// Optional custom haptic feedback. Defaults to [Haptics.light].
  final VoidCallback? haptic;

  /// 启用毛玻璃模糊。滚动列表内条目保持 false 以保性能与可读性。
  final bool frosted;

  /// 是否对齐无障碍触摸目标，强制 [GestureDetector] 命中区 ≥48×48。
  ///
  /// 默认 true，适配卡片、列表项等大尺寸可点击块。仅当本组件作为内在
  /// 高度小于 48 的小型 chip 使用时置 false——否则 `minHeight:48` 会把
  /// chip 沿垂直方向撑高，配合 `borderRadius` 渲染成又圆又胖的 stadium。
  /// 关闭后点击仍可用，调用方应确保 chip 间距/行高足以容纳手指点按。
  final bool minTapTarget;

  @override
  State<BentoTile> createState() => _BentoTileState();
}

class _BentoTileState extends State<BentoTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final solid = !widget.frosted && widget.gradient == null
        ? (widget.color ?? scheme.surface)
        : null;

    Widget content = AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 90),
      child: SizedBox(
        height: widget.height,
        width: widget.width,
        child: _TileSurface(
          frosted: widget.frosted,
          radius: widget.borderRadius,
          padding: widget.padding,
          border: widget.border,
          shadow: widget.shadow,
          gradient: widget.gradient,
          solidColor: solid,
          child: widget.child,
        ),
      ),
    );

    if (_down) {
      content = ColorFiltered(
        colorFilter: ColorFilter.mode(
          // 冷调按下叠层：ink @ 8%。
          scheme.onSurface.withValues(alpha: 0.08),
          BlendMode.srcATop,
        ),
        child: content,
      );
    }

    if (widget.onTap == null) return content;

    final gesture = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        (widget.haptic ?? Haptics.light)();
        widget.onTap!();
      },
      child: content,
    );
    if (!widget.minTapTarget) return gesture;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: gesture,
    );
  }
}

/// 实心面或玻璃面二选一，不重构子树布局。
class _TileSurface extends StatelessWidget {
  const _TileSurface({
    required this.child,
    required this.frosted,
    required this.radius,
    required this.padding,
    required this.border,
    required this.shadow,
    required this.gradient,
    required this.solidColor,
  });

  final Widget child;
  final bool frosted;
  final double radius;
  final EdgeInsetsGeometry padding;
  final BoxBorder? border;
  final BoxShadow? shadow;
  final Gradient? gradient;
  final Color? solidColor;

  @override
  Widget build(BuildContext context) {
    // 实心面：DecoratedBox 直接画底色 + 描边 + 阴影（无模糊开销）。
    if (solidColor != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: solidColor,
          borderRadius: BorderRadius.circular(radius),
          border: border,
          boxShadow: shadow != null ? [shadow!] : null,
        ),
        child: Padding(padding: padding, child: child),
      );
    }

    // 玻璃面 / 渐变面：复用 GlassSurface。
    return GlassSurface(
      frosted: frosted,
      radius: radius,
      padding: padding,
      border: border,
      shadow: shadow,
      gradient: gradient,
      child: child,
    );
  }
}
