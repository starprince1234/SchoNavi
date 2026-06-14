import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/launcher/link_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../providers/competition_recommendation_provider.dart';
import '../widgets/competition_card.dart';
import '../widgets/competition_query_understanding_card.dart';

class CompetitionRecommendationPage extends ConsumerStatefulWidget {
  const CompetitionRecommendationPage({super.key, required this.prompt});

  final String prompt;

  @override
  ConsumerState<CompetitionRecommendationPage> createState() =>
      _CompetitionRecommendationPageState();
}

class _CompetitionRecommendationPageState
    extends ConsumerState<CompetitionRecommendationPage> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(competitionRecommendationProvider(widget.prompt));
    return Scaffold(
      appBar: AppBar(title: const Text('竞赛推荐')),
      body: async.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            CompetitionCardSkeleton(),
            SizedBox(height: 8),
            CompetitionCardSkeleton(),
            SizedBox(height: 8),
            CompetitionCardSkeleton(),
          ],
        ),
        error: (e, _) => ErrorView(
          message: e is AppException ? e.message : '出错了，请稍后重试',
          onRetry: () =>
              ref.invalidate(competitionRecommendationProvider(widget.prompt)),
        ),
        data: (result) {
          if (result.recommendations.isEmpty) {
            return EmptyView(
              message: '暂未找到匹配的竞赛。\n可补充专业方向、团队偏好或报名时间。',
              actionLabel: '修改条件',
              onAction: () => context.pop(),
            );
          }
          return RefreshIndicator(
            color: AppColors.coral,
            onRefresh: () async {
              ref.invalidate(competitionRecommendationProvider(widget.prompt));
              await ref.read(
                competitionRecommendationProvider(widget.prompt).future,
              );
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CompetitionQueryUnderstandingCard(
                  understanding: result.understanding,
                ),
                const SizedBox(height: 8),
                ...result.recommendations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final competition = entry.value;
                  return AnimatedEntrance(
                    index: index,
                    child: CompetitionCard(
                      competition: competition,
                      onOpenOfficialPressed: () =>
                          _openOfficial(context, competition.officialUrl),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openOfficial(BuildContext context, String? url) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(linkLauncherProvider).open(url);
    switch (result) {
      case LaunchResult.success:
        return;
      case LaunchResult.noUrl:
        messenger.showSnackBar(
          const SnackBar(content: Text('暂无官网信息，请以学校或赛事官方通知为准')),
        );
      case LaunchResult.failed:
        messenger.showSnackBar(
          const SnackBar(content: Text('官网可能暂时无法打开，请以赛事官方通知为准')),
        );
    }
  }
}
