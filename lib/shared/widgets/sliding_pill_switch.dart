import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_colors.dart';

/// A compact, controlled sliding-pill tab switcher.
///
/// The visual pill is 36 dp tall with an 18 dp border radius. Each option is
/// guaranteed a tappable area of at least 44×44 dp, even though the visible
/// pill itself stays at 36 dp high.
class SlidingPillSwitch<T> extends StatelessWidget {
  const SlidingPillSwitch({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.labels,
    this.icons,
  })  : assert(labels.length == values.length, 'labels must match values'),
        assert(
          icons == null || icons.length == values.length,
          'icons must match values when provided',
        );

  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final List<String> labels;
  final List<IconData>? icons;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selectedIndex = values.indexOf(selected);

    assert(
      selectedIndex >= 0,
      'selected value must be one of the provided values',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final optionWidth = max(
          constraints.hasBoundedWidth
              ? constraints.maxWidth / values.length
              : 0.0,
          44.0,
        );
        final totalWidth = optionWidth * values.length;

        return SizedBox(
          height: 44,
          width: totalWidth,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background track.
              Container(
                height: 30,
                width: totalWidth,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              // Sliding selected pill.
              AnimatedPositioned(
                left: selectedIndex >= 0 ? selectedIndex * optionWidth : 0,
                top: 7,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: AnimatedContainer(
                  width: optionWidth,
                  height: 30,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: AppColors.coral,
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              // Tappable options.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < values.length; i++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Haptics.selection();
                        onChanged(values[i]);
                      },
                      child: Container(
                        width: optionWidth,
                        height: 44,
                        alignment: Alignment.center,
                        child: _OptionContent(
                          label: labels[i],
                          icon: icons?[i],
                          selected: i == selectedIndex,
                          fontSize: textTheme.labelMedium?.fontSize ?? 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OptionContent extends StatelessWidget {
  const _OptionContent({
    required this.label,
    required this.selected,
    required this.fontSize,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;

    final text = Text(
      label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );

    if (icon == null) return text;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        text,
      ],
    );
  }
}
