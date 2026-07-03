import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import 'glass_surface.dart';

/// 圆形玻璃悬浮按钮：复用于首页与对话页的左上/右上操作位。
///
/// 视觉：GlassSurface 圆形底 + 居中 Icon，直径 44，符合 Material 最小触控。
/// 与 CoolScaffoldBackground 叠加时呈半透明毛玻璃，避免实体栏遮挡内容。
/// [onPressed] 为 null 时进入 disabled 态：icon 变灰、无 ripple。
class FloatingTopButton extends StatelessWidget {
  const FloatingTopButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;

  final String tooltip;

  /// null = disabled（icon 灰、无点击）。
  final VoidCallback? onPressed;

  bool get _disabled => onPressed == null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = _disabled ? scheme.onSurfaceVariant : scheme.onSurface;
    return Tooltip(
      message: tooltip,
      child: GlassSurface(
        frosted: true,
        radius: 22, // 直径 44 / 2
        padding: EdgeInsets.zero,
        border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _disabled
                ? null
                : () {
                    Haptics.light();
                    onPressed!();
                  },
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 22, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
