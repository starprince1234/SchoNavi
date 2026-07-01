import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_colors.dart';

/// A compact, tappable tag used for quick filters or shortcuts.
///
/// Unlike [BentoTile], this widget does not enforce a 48dp minimum tap target,
/// so it fits tightly around its label text. It keeps the same bento-style
/// rounded container, soft shadow, and press feedback.
class QuickTag extends StatefulWidget {
  const QuickTag({
    super.key,
    required this.label,
    this.onTap,
    this.color,
    this.haptic,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final VoidCallback? haptic;

  @override
  State<QuickTag> createState() => _QuickTagState();
}

class _QuickTagState extends State<QuickTag> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget content = AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 90),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: widget.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [AppColors.shadowCool],
        ),
        child: Text(
          widget.label,
          style: textTheme.labelSmall?.copyWith(color: scheme.onSurface),
        ),
      ),
    );

    if (_down) {
      content = ColorFiltered(
        colorFilter: ColorFilter.mode(
          scheme.onSurface.withValues(alpha: 0.10),
          BlendMode.srcATop,
        ),
        child: content,
      );
    }

    if (widget.onTap == null) return content;

    return GestureDetector(
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
  }
}
