import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/llm_trace.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/launcher/link_launcher.dart';
import '../../../domain/entities/favorite_item.dart';
import '../../../domain/entities/recommendation_result.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/professor_card.dart';
import '../providers/recommendation_provider.dart';
import '../widgets/query_understanding_card.dart';

class RecommendationPage extends ConsumerStatefulWidget {
  const RecommendationPage({super.key, required this.prompt});

  final String prompt;

  @override
  ConsumerState<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends ConsumerState<RecommendationPage> {
  String? _recordedSessionId;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recommendationProvider(widget.prompt));
    return Scaffold(
      appBar: AppBar(title: const Text('推荐结果')),
      floatingActionButton: async.maybeWhen(
        data: (result) => result.recommendations.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => context.push(
                  '/chat?sid=${Uri.encodeComponent(result.sessionId)}',
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('继续追问'),
              ),
        orElse: () => null,
      ),
      body: async.when(
        loading: () => const LoadingView(label: '正在为你匹配导师…'),
        error: (e, _) => ErrorView(
          message: e is AppException ? e.message : '出错了，请稍后重试',
          onRetry: () => ref.invalidate(recommendationProvider(widget.prompt)),
        ),
        data: (result) {
          _recordHistoryOnce(result);
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
              ...result.recommendations.map((r) {
                final isFavorite = ref
                    .watch(favoriteStatusProvider(r.professorId))
                    .maybeWhen(data: (value) => value, orElse: () => false);
                return ProfessorCard(
                  recommendation: r,
                  isFavorite: isFavorite,
                  onTap: () => context.push('/professor/${r.professorId}'),
                  onFavoritePressed: () => ref
                      .read(favoriteRepositoryProvider)
                      .toggle(FavoriteItem.fromRecommendation(r)),
                  onOpenHomepagePressed: () =>
                      _openHomepage(context, r.homepageUrl),
                );
              }),
              const _AiTracePanel(),
            ],
          );
        },
      ),
    );
  }

  void _recordHistoryOnce(RecommendationResult result) {
    if (_recordedSessionId == result.sessionId) return;
    _recordedSessionId = result.sessionId;
    unawaited(
      ref
          .read(historyRepositoryProvider)
          .addFromResult(prompt: widget.prompt, result: result),
    );
  }

  Future<void> _openHomepage(BuildContext context, String? url) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(linkLauncherProvider).open(url);
    switch (result) {
      case LaunchResult.success:
        return;
      case LaunchResult.noUrl:
        messenger.showSnackBar(const SnackBar(content: Text('暂无主页信息')));
      case LaunchResult.failed:
        messenger.showSnackBar(
          const SnackBar(content: Text('主页可能已失效，可通过学校官网确认')),
        );
    }
  }
}

/// 仅演示模式（showAiTrace）且已有最近调用快照时显示，体现"AI 透明化"。
/// 视觉沿用 Bento 主题：Card(16 圆角 + 描边) + ExpansionTile，珊瑚 leading。
class _AiTracePanel extends ConsumerWidget {
  const _AiTracePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTrace = ref.watch(
      appConfigProvider.select((c) => c.featureFlags.showAiTrace),
    );
    final trace = ref.watch(aiTraceProvider);
    if (!showTrace || trace == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: ExpansionTile(
          leading: Icon(Icons.science_outlined, color: scheme.secondary),
          title: Text('查看 AI 详情', style: textTheme.titleMedium),
          subtitle: Text(
            '本次大模型调用快照（演示模式）',
            style: textTheme.bodySmall,
          ),
          shape: const Border(),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '模型：${trace.model}（${trace.elapsedMs} ms）',
                style: textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('实际 prompt', style: textTheme.labelLarge),
            ),
            for (final m in trace.messages)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: SelectableText('[${m.role}] ${m.content}'),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('原始返回', style: textTheme.labelLarge),
            ),
            SelectableText(trace.rawResponse),
          ],
        ),
      ),
    );
  }
}
