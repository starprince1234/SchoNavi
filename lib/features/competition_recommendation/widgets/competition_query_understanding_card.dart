import 'package:flutter/material.dart';

import '../../../domain/entities/competition_query_understanding.dart';

class CompetitionQueryUnderstandingCard extends StatelessWidget {
  const CompetitionQueryUnderstandingCard({
    super.key,
    required this.understanding,
  });

  final CompetitionQueryUnderstanding understanding;

  @override
  Widget build(BuildContext context) {
    final u = understanding;
    final textTheme = Theme.of(context).textTheme;

    String join(List<String> values) =>
        values.isEmpty ? '暂无信息' : values.join('、');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('我理解到的竞赛需求', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('方向偏好：${join(u.directions)}'),
            Text('赛事类别：${join(u.categories)}'),
            Text('时间偏好：${join(u.timingPreferences)}'),
            Text('组队偏好：${join(u.teamPreferences)}'),
            if (u.uncertainties.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('待确认：', style: textTheme.labelLarge),
              ...u.uncertainties.map(
                (item) => Text('- $item', style: textTheme.bodySmall),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
