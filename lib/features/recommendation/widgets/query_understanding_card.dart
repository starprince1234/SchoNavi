import 'package:flutter/material.dart';

import '../../../domain/entities/query_understanding.dart';

class QueryUnderstandingCard extends StatelessWidget {
  const QueryUnderstandingCard({super.key, required this.understanding});

  final QueryUnderstanding understanding;

  @override
  Widget build(BuildContext context) {
    final u = understanding;
    final textTheme = Theme.of(context).textTheme;

    String join(List<String> xs) => xs.isEmpty ? '暂无信息' : xs.join('、');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('我理解到的需求', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('研究方向：${join(u.researchInterests)}'),
            Text('地域偏好：${join(u.preferredLocations)}'),
            Text('学历阶段：${u.degreeStage ?? '暂无信息'}'),
            if (u.uncertainties.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('待确认：', style: textTheme.labelLarge),
              ...u.uncertainties.map(
                (x) => Text(
                  '· $x',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
