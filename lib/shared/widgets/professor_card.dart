import 'package:flutter/material.dart';

import '../../domain/entities/recommendation.dart';
import 'field_chips.dart';
import 'match_level_chip.dart';

class ProfessorCard extends StatelessWidget {
  const ProfessorCard({
    super.key,
    required this.recommendation,
    required this.onTap,
  });

  final Recommendation recommendation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = recommendation;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, style: textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(r.title, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                  MatchLevelChip(level: r.matchLevel),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${r.university} / ${r.college}',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              FieldChips(fields: r.researchFields),
              const SizedBox(height: 10),
              Text(
                '推荐理由：${r.reason}',
                style: textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
