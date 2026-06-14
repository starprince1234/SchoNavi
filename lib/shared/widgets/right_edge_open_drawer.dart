import 'package:flutter/material.dart';

/// A transparent vertical strip that opens the end drawer when the user swipes
/// leftward from the right edge of the screen.
///
/// The widget is sized to the full height of its parent and only occupies
/// [edgeWidth] logical pixels on the right side. Place it inside a [Stack]
/// (usually with [Positioned]) on top of the page content.
class RightEdgeOpenDrawer extends StatelessWidget {
  const RightEdgeOpenDrawer({
    super.key,
    required this.onSwipe,
    this.edgeWidth = 28.0,
    this.minVelocity = -300.0,
  }) : assert(minVelocity <= 0, 'minVelocity must be zero or negative');

  /// Called when a leftward swipe from the right edge is detected.
  final VoidCallback onSwipe;

  /// Width of the sensitive strip along the right edge.
  final double edgeWidth;

  /// Minimum horizontal velocity (px/s) that triggers [onSwipe].
  /// Must be zero or negative because a leftward swipe has a negative velocity.
  final double minVelocity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: edgeWidth,
      height: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity;
          if (velocity != null && velocity < minVelocity) {
            onSwipe();
          }
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}
