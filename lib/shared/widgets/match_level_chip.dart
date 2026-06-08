import 'package:flutter/material.dart';

import '../../domain/entities/match_level.dart';

class MatchLevelChip extends StatelessWidget {
  const MatchLevelChip({super.key, required this.level});

  final MatchLevel level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (level) {
      MatchLevel.high => (scheme.primary, scheme.onPrimary),
      MatchLevel.medium => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      MatchLevel.low => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '匹配度：${level.label}',
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
