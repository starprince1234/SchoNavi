import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/favorite_item.dart';
import '../../../domain/entities/recommendation.dart';
import '../../../shared/widgets/swipe_recommendation_card.dart';

/// 对话气泡下方的横向滑动推荐轨道（PageView 一次一张 + page indicator）。
///
/// 借鉴约会 APP「刷卡片」：[PageView] + `viewportFraction` 露出下一张边缘作
/// 「可滑」暗示，切页触发 [Haptics.selection]；底部圆点 indicator 指示位置，
/// 卡片 ≤1 张时隐藏。固定高度避免 ListView 嵌套无限高异常（spec §3.2）。
/// 收藏状态由内部 watch `favoriteStatusProvider`，主页回调由父层注入。
class RecommendationCarousel extends ConsumerStatefulWidget {
  const RecommendationCarousel({
    super.key,
    required this.recommendations,
    required this.onTap,
    this.onOpenHomepage,
    this.height,
  });

  final List<Recommendation> recommendations;
  final void Function(String professorId) onTap;
  final void Function(Recommendation recommendation)? onOpenHomepage;
  final double? height;

  @override
  ConsumerState<RecommendationCarousel> createState() =>
      _RecommendationCarouselState();
}

class _RecommendationCarouselState
    extends ConsumerState<RecommendationCarousel> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.86);
  }

  @override
  void didUpdateWidget(covariant RecommendationCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recommendations.isEmpty) {
      _page = 0;
      return;
    }
    final maxPage = widget.recommendations.length - 1;
    if (_page <= maxPage) return;
    _page = maxPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) {
        _controller.jumpToPage(_page);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recommendations.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final effectiveHeight =
        widget.height ?? (250 + (textScale - 1).clamp(0, 1) * 54);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: effectiveHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.recommendations.length,
            onPageChanged: (index) {
              Haptics.selection();
              if (mounted) setState(() => _page = index);
            },
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final r = widget.recommendations[index];
              final isFavorite = ref
                  .watch(favoriteStatusProvider(r.professorId))
                  .maybeWhen(data: (v) => v, orElse: () => false);
              return Semantics(
                label:
                    '第 ${index + 1} 张，共 ${widget.recommendations.length} 张，'
                    '${r.name}，${r.university}',
                container: true,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SwipeRecommendationCard(
                    recommendation: r,
                    isFavorite: isFavorite,
                    onTap: () => widget.onTap(r.professorId),
                    onFavoritePressed: () => ref
                        .read(favoriteRepositoryProvider)
                        .toggle(FavoriteItem.fromRecommendation(r)),
                    onOpenHomepagePressed: widget.onOpenHomepage == null
                        ? null
                        : () => widget.onOpenHomepage!(r),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.recommendations.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.recommendations.length, (i) {
              final active = i == _page;
              return Container(
                key: Key('rec-indicator-$i'),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 7 : 6,
                height: active ? 7 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.coral
                      : scheme.outline.withValues(alpha: 0.4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
