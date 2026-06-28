import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/competition_recommendation_result.dart';
import '../../../shared/widgets/recommendation_card_data.dart';
import '../../../shared/widgets/swipe_card_carousel.dart';
import '../../../shared/widgets/swipe_recommendation_card.dart';
import '../mappers/competition_card_mapper.dart';
import '../providers/competition_home_notifier.dart';
import 'competition_query_understanding_card.dart';

/// 首页原地结果视图：把 [CompetitionHomeState] 渲染为输入区下方的结果区域。
///
/// - idle：空占位
/// - loading：用户气泡 + 正在思考占位
/// - result：用户气泡 + 助手摘要 + 需求理解卡 + 横滑推荐卡 + 调整条件按钮
/// - empty：用户气泡 + 空提示 + 调整条件按钮
/// - error：用户气泡 + 错误文案 + 重试按钮
class CompetitionHomeResultView extends StatelessWidget {
  const CompetitionHomeResultView({
    super.key,
    required this.state,
    required this.onAdjust,
    required this.onRetry,
    this.prompt,
    this.onOpenDetail,
  });

  final CompetitionHomeState state;
  final VoidCallback onAdjust;
  final Future<void> Function(String prompt) onRetry;

  /// 父层传入的原始 prompt。
  ///
  /// 用于 result / empty / error 下落稳态渲染用户消息气泡；loading 取用
  /// [CompetitionHomeLoading.prompt]。
  final String? prompt;

  /// 点击竞赛卡片时回调竞赛 id；由外层负责路由跳转。
  final void Function(String competitionId)? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      CompetitionHomeIdle() => const SizedBox.shrink(),
      CompetitionHomeLoading(:final prompt) => _buildLoading(context, prompt),
      CompetitionHomeResult(:final data) => _buildResult(context, data),
      CompetitionHomeEmpty() => _buildEmpty(context),
      CompetitionHomeError(:final message) => _buildError(context, message),
    };
  }

  Widget _buildLoading(BuildContext context, String prompt) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserMessageBubble(text: prompt),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: AppColors.indigo),
              const SizedBox(width: 8),
              Text(
                '正在为你匹配竞赛…',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, CompetitionRecommendationResult data) {
    final recs = data.recommendations;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserMessageBubble(text: prompt),
          const SizedBox(height: 16),
          _buildSummary(context, data),
          const SizedBox(height: 16),
          CompetitionQueryUnderstandingCard(understanding: data.understanding),
          const SizedBox(height: 16),
          SwipeCardCarousel<RecommendationCardData>(
            height: 260,
            items: recs.map((c) => c.toCardData()).toList(growable: false),
            semanticsLabel: (d) => d.title,
            itemBuilder: (context, cardData, index) {
              final source = recs[index];
              return SwipeRecommendationCard(
                data: cardData,
                onTap: () => onOpenDetail?.call(source.id),
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: onAdjust,
              child: const Text('调整条件'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, CompetitionRecommendationResult data) {
    final u = data.understanding;
    final directions = u.directions.isEmpty ? null : u.directions.join('、');
    final categories = u.categories.isEmpty ? null : u.categories.join('、');
    final buffer = StringBuffer('我理解了');
    if (directions != null) {
      buffer.write('你对「$directions」方向');
    }
    if (categories != null) {
      buffer.write('${directions != null ? '的' : ''}$categories类竞赛');
    }
    if (directions == null && categories == null) {
      buffer.write('你的竞赛需求');
    }
    buffer.write('，为你推荐以下竞赛：');
    return Text(
      buffer.toString(),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserMessageBubble(text: prompt),
          const SizedBox(height: 16),
          Text(
            '暂无匹配竞赛，试试调整条件',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkSoft,
                ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onAdjust,
            child: const Text('调整条件'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserMessageBubble(text: prompt),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: prompt == null ? null : () async => onRetry(prompt!),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// 简化的右对齐用户消息气泡，使用应用统一的 indigoSoft 底色。
class _UserMessageBubble extends StatelessWidget {
  const _UserMessageBubble({this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final content = text;
    if (content == null || content.isEmpty) {
      return const SizedBox.shrink();
    }
    final width = MediaQuery.sizeOf(context).width * 0.78;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.indigoSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
