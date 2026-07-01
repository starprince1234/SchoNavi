import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';
import 'bento_tile.dart';

/// A large, finger-friendly action tile with a centered icon and label.
///
/// Internally uses [BentoTile] for consistent bento styling and press
/// feedback. Minimum height is 80 logical pixels.
class BentoActionTile extends StatelessWidget {
  const BentoActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BentoTile(
      onTap: onTap != null
          ? () {
              Haptics.medium();
              onTap!();
            }
          : null,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: iconColor ?? scheme.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
