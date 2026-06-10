import 'package:flutter/material.dart';

/// Animated statistic tile: counts from 0 to [value].
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.color,
    this.duration = const Duration(milliseconds: 900),
  });

  final int value;
  final String label;
  final Color? color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberColor = color ?? theme.colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: value),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => Text(
            '$v',
            style: theme.textTheme.displaySmall?.copyWith(color: numberColor),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}
