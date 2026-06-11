import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';

/// Bento tile with press feedback and optional tap behavior.
///
/// When [onTap] is provided, the gesture area is constrained to a minimum
/// of 48x48 logical pixels to meet accessibility tap-target guidelines.
class BentoTile extends StatefulWidget {
  const BentoTile({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.padding = const EdgeInsets.all(14),
    this.border,
    this.shadow = const BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    this.gradient,
    this.borderRadius = 18,
    this.height,
    this.width,
    this.haptic,
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

  @override
  State<BentoTile> createState() => _BentoTileState();
}

class _BentoTileState extends State<BentoTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget content = AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 90),
      child: Container(
        height: widget.height,
        width: widget.width,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.gradient == null ? (widget.color ?? scheme.surface) : null,
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.border,
          boxShadow: widget.shadow != null ? [widget.shadow!] : null,
        ),
        child: widget.child,
      ),
    );

    if (_down) {
      content = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0x1A000000),
          BlendMode.srcATop,
        ),
        child: content,
      );
    }

    if (widget.onTap == null) return content;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 48,
        minHeight: 48,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          (widget.haptic ?? Haptics.light)();
          widget.onTap!();
        },
        child: content,
      ),
    );
  }
}
