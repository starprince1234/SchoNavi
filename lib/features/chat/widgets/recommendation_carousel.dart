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
  // 连续页值（含动画中间态），驱动纵深降权。每帧由 listener 推送。
  double _pageFloat = 0;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.86);
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final page = _controller.hasClients ? (_controller.page ?? 0.0) : 0.0;
    if ((page - _pageFloat).abs() < 0.001) return;
    setState(() => _pageFloat = page);
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
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  /// 非当前卡降权：距中心越远 scale 越小、opacity 越低，在 |Δ|≤1 内线性。
  ({double scale, double opacity}) _dampFor(int index) {
    final delta = (index - _pageFloat).abs();
    if (delta >= 1) return (scale: 0.92, opacity: 0.55);
    // 当前张 delta=0 → scale 1 / opacity 1；邻张 delta=1 → 0.92 / 0.55。
    final t = delta; // 0..1
    return (
      scale: 1 - (1 - 0.92) * t,
      opacity: 1 - (1 - 0.55) * t,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recommendations.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperColor = AppColors.paperOf(isDark);
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final effectiveHeight =
        widget.height ?? (250 + (textScale - 1).clamp(0, 1) * 54);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
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
                  final d = _dampFor(index);
                  return Semantics(
                    label:
                        '第 ${index + 1} 张，共 ${widget.recommendations.length} 张，'
                        '${r.name}，${r.university}',
                    container: true,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: AnimatedScale(
                        scale: d.scale,
                        duration: const Duration(milliseconds: 60),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 60),
                          opacity: d.opacity,
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
                      ),
                    ),
                  );
                },
              ),
            ),
            // 边缘渐隐遮罩：暗示「还有更多可滑」。IgnorePointer 不拦截手势。
            if (widget.recommendations.length > 1) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: Row(
                    children: [
                      _EdgeFade(color: paperColor, side: _EdgeSide.left),
                      const Spacer(),
                      _EdgeFade(color: paperColor, side: _EdgeSide.right),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        if (widget.recommendations.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.recommendations.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                key: Key('rec-indicator-$i'),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: active
                      ? AppColors.indigo
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

enum _EdgeSide { left, right }

/// 横向渐隐遮罩：从 [color] 端渐变到透明，宽度 28，营造「可滑」边缘暗示。
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.color, required this.side});

  final Color color;
  final _EdgeSide side;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: side == _EdgeSide.left
              ? Alignment.centerLeft
              : Alignment.centerRight,
          end: side == _EdgeSide.left
              ? Alignment.centerRight
              : Alignment.centerLeft,
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
