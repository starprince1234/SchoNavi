import 'package:flutter/material.dart';

import 'animated_entrance.dart';

/// A reusable bento-style grid that lays out children in [crossAxisCount]
/// columns using [Wrap].
///
/// Each child can have a different height, unlike a rigid [GridView].
/// Supports optional staggered entrance animations via [animateEntrance].
class BentoGrid extends StatelessWidget {
  const BentoGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.spacing = 12,
    this.runSpacing = 12,
    this.animateEntrance = true,
    this.padding,
  });

  final List<Widget> children;
  final int crossAxisCount;
  final double spacing;
  final double runSpacing;
  final bool animateEntrance;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = spacing * (crossAxisCount - 1);
        final itemWidth =
            (constraints.maxWidth - totalSpacing) / crossAxisCount;

        final wrapped = children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          final sized = SizedBox(width: itemWidth, child: child);

          if (!animateEntrance) return sized;

          return AnimatedEntrance(
            index: index,
            child: sized,
          );
        }).toList();

        return Padding(
          padding: padding ?? EdgeInsets.zero,
          child: Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: wrapped,
          ),
        );
      },
    );
  }
}
