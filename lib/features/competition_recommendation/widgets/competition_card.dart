import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/recommended_competition.dart';
import '../../../shared/widgets/field_chips.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';

class CompetitionCard extends StatelessWidget {
  const CompetitionCard({
    super.key,
    required this.competition,
    required this.onOpenOfficialPressed,
  });

  final RecommendedCompetition competition;
  final VoidCallback onOpenOfficialPressed;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    final theme = Theme.of(context);
    final scoreLabel = '${(c.matchScore * 100).round()}%';

    return Semantics(
      label: '竞赛推荐：${c.name}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.indigoSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      color: AppColors.indigo,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${c.category} / ${c.level}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MatchScoreChip(label: scoreLabel),
                ],
              ),
              const SizedBox(height: 12),
              FieldChips(fields: c.tags),
              const SizedBox(height: 12),
              _MetaRow(
                icon: Icons.event_available_outlined,
                label: '报名',
                value: c.signupTime,
              ),
              _MetaRow(
                icon: Icons.flag_outlined,
                label: '比赛',
                value: c.contestTime,
              ),
              _MetaRow(
                icon: Icons.groups_2_outlined,
                label: '规模',
                value: c.teamSize,
              ),
              _MetaRow(
                icon: Icons.assignment_outlined,
                label: '形式',
                value: c.format,
              ),
              _MetaRow(
                icon: Icons.account_balance_outlined,
                label: '主办',
                value: c.organizer,
              ),
              const SizedBox(height: 10),
              Text('推荐理由', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(c.reason, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              Text('备赛重点', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              ...c.preparationTips.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('- $tip', style: theme.textTheme.bodySmall),
                ),
              ),
              if (c.limitations.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...c.limitations.map(
                  (item) => Text(
                    item,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: '访问${c.name}官网',
                  child: TextButton.icon(
                    onPressed: onOpenOfficialPressed,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('访问官网'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchScoreChip extends StatelessWidget {
  const _MatchScoreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cyanSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.cyan,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.inkSoft),
          const SizedBox(width: 6),
          SizedBox(
            width: 38,
            child: Text(label, style: theme.textTheme.labelSmall),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class CompetitionCardSkeleton extends StatelessWidget {
  const CompetitionCardSkeleton({super.key});

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
                ShimmerSkeleton(width: 42, height: 42),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerSkeleton(height: 18, width: 180),
                      SizedBox(height: 6),
                      ShimmerSkeleton(height: 12, width: 100),
                    ],
                  ),
                ),
                ShimmerSkeleton(height: 24, width: 48),
              ],
            ),
            SizedBox(height: 12),
            ShimmerSkeleton(height: 12, width: double.infinity),
            SizedBox(height: 6),
            ShimmerSkeleton(height: 12, width: double.infinity),
            SizedBox(height: 6),
            ShimmerSkeleton(height: 12, width: 220),
          ],
        ),
      ),
    );
  }
}
