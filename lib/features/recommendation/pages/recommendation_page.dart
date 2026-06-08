import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/professor_card.dart';
import '../providers/recommendation_provider.dart';
import '../widgets/query_understanding_card.dart';

class RecommendationPage extends ConsumerWidget {
  const RecommendationPage({super.key, required this.prompt});

  final String prompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recommendationProvider(prompt));
    return Scaffold(
      appBar: AppBar(title: const Text('推荐结果')),
      body: async.when(
        loading: () => const LoadingView(label: '正在为你匹配导师…'),
        error: (e, _) => ErrorView(
          message: e is AppException ? e.message : '出错了，请稍后重试',
          onRetry: () => ref.invalidate(recommendationProvider(prompt)),
        ),
        data: (result) {
          if (result.recommendations.isEmpty) {
            return EmptyView(
              message: '暂未找到完全符合条件的导师。\n可尝试放宽学校、地区或研究方向限制。',
              actionLabel: '修改条件',
              onAction: () => context.pop(),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              QueryUnderstandingCard(understanding: result.queryUnderstanding),
              const SizedBox(height: 8),
              ...result.recommendations.map(
                (r) => ProfessorCard(
                  recommendation: r,
                  onTap: () => context.push('/professor/${r.professorId}'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
