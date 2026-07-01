import 'package:flutter/material.dart';

/// A shimmering loading skeleton that loops continuously.
///
/// Renders an animated linear gradient sweep over a base surface.
class ShimmerSkeleton extends StatefulWidget {
  const ShimmerSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.child,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? child;

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = scheme.surfaceContainerLowest;
    final shimmerColor = scheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final gradient = LinearGradient(
              colors: [baseColor, shimmerColor, baseColor],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(-1 + (_controller.value * 3), 0),
              end: Alignment(0 + (_controller.value * 3), 0),
            );
            return gradient.createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: child,
        );
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        ),
        child: widget.child,
      ),
    );
  }
}

/// A preset shimmer layout that mimics a [ProfessorCard].
class ProfessorCardSkeleton extends StatelessWidget {
  const ProfessorCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerSkeleton(height: 18, width: 120),
                      SizedBox(height: 6),
                      ShimmerSkeleton(height: 12, width: 80),
                    ],
                  ),
                ),
                ShimmerSkeleton(height: 24, width: 48),
              ],
            ),
            SizedBox(height: 10),
            ShimmerSkeleton(height: 12, width: 160),
            SizedBox(height: 10),
            ShimmerSkeleton(height: 12, width: double.infinity),
            SizedBox(height: 6),
            ShimmerSkeleton(height: 12, width: double.infinity),
            SizedBox(height: 6),
            ShimmerSkeleton(height: 12, width: 200),
          ],
        ),
      ),
    );
  }
}
