import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';

/// Bento tile with press feedback and optional tap behavior.
class BentoTile extends StatefulWidget {
  const BentoTile({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.padding = const EdgeInsets.all(14),
    this.border,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final BoxBorder? border;

  @override
  State<BentoTile> createState() => _BentoTileState();
}

class _BentoTileState extends State<BentoTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tile = AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 90),
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: widget.border,
        ),
        child: widget.child,
      ),
    );

    if (widget.onTap == null) return tile;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        Haptics.light();
        widget.onTap!();
      },
      child: tile,
    );
  }
}
