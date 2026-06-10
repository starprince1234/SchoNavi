import 'package:flutter/material.dart';

/// Section title with optional coral leading marker.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.accent = true});

  final String title;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (accent) ...[
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(title, style: theme.textTheme.titleLarge),
      ],
    );
  }
}
