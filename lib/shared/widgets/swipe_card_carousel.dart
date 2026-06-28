import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_colors.dart';

/// 通用横滑卡轨道：分页/缩放/胶囊指示器/边缘渐隐/触觉/语义/大字体自适应。
/// 卡片内容由 [itemBuilder] 提供，组件不感知数据类型。
class SwipeCardCarousel<T> extends StatefulWidget {
  const SwipeCardCarousel({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.semanticsLabel,
    this.height,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final String Function(T item) semanticsLabel;
  final double? height;

  @override
  State<SwipeCardCarousel<T>> createState() => _SwipeCardCarouselState<T>();
}

class _SwipeCardCarouselState<T> extends State<SwipeCardCarousel<T>> {
  late final PageController _controller;
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
  void didUpdateWidget(covariant SwipeCardCarousel<T> old) {
    super.didUpdateWidget(old);
    if (widget.items.isEmpty) { _page = 0; return; }
    final maxPage = widget.items.length - 1;
    if (_page <= maxPage) return;
    _page = maxPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) _controller.jumpToPage(_page);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  ({double scale, double opacity}) _dampFor(int index) {
    final delta = (index - _pageFloat).abs();
    if (delta >= 1) return (scale: 0.92, opacity: 0.55);
    final t = delta;
    return (scale: 1 - (1 - 0.92) * t, opacity: 1 - (1 - 0.55) * t);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperColor = AppColors.paperOf(isDark);
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final h = widget.height ?? (250 + (textScale - 1).clamp(0, 1) * 54);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(children: [
          SizedBox(
            height: h,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (i) { Haptics.selection(); if (mounted) setState(() => _page = i); },
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final d = _dampFor(index);
                return Semantics(
                  label: '第 ${index + 1} 张，共 ${widget.items.length} 张，'
                      '${widget.semanticsLabel(widget.items[index])}',
                  container: true,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: AnimatedScale(
                      scale: d.scale,
                      duration: const Duration(milliseconds: 60),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 60),
                        opacity: d.opacity,
                        child: widget.itemBuilder(context, widget.items[index], index),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.items.length > 1)
            Positioned.fill(child: IgnorePointer(child: Row(children: [
              _EdgeFade(color: paperColor, side: _EdgeSide.left),
              const Spacer(),
              _EdgeFade(color: paperColor, side: _EdgeSide.right),
            ]))),
        ]),
        if (widget.items.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.items.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                key: Key('carousel-indicator-$i'),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: active ? AppColors.indigo : scheme.outline.withValues(alpha: 0.4),
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
          begin: side == _EdgeSide.left ? Alignment.centerLeft : Alignment.centerRight,
          end: side == _EdgeSide.left ? Alignment.centerRight : Alignment.centerLeft,
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
