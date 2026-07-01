import 'dart:async';

import 'package:flutter/material.dart';

/// Reusable staggered entrance animation wrapper.
///
/// Applies a fade + slide animation to [child]. The delay is derived from
/// [index] multiplied by [staggerDelay], making it ideal for lists and grids.
class AnimatedEntrance extends StatefulWidget {
  const AnimatedEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 360),
    this.staggerDelay = const Duration(milliseconds: 60),
    this.slideOffset = const Offset(0, 16),
  });

  final Widget child;

  /// Item index used to compute stagger delay.
  final int index;

  /// Base delay before the animation starts.
  final Duration delay;

  /// Animation duration.
  final Duration duration;

  /// Delay between each item when used in a list.
  final Duration staggerDelay;

  /// Starting offset for the slide animation.
  final Offset slideOffset;

  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final staggered = widget.delay + (widget.staggerDelay * widget.index);

    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 1, curve: Curves.easeOut),
      ),
    );

    _slide = Tween<Offset>(begin: widget.slideOffset, end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 1, curve: Curves.easeOutCubic),
      ),
    );

    if (staggered == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(staggered, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(offset: _slide.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Automatically wraps a list of [children] with staggered [AnimatedEntrance]
/// animations.
class AnimatedEntranceList extends StatelessWidget {
  const AnimatedEntranceList({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 360),
    this.slideOffset = const Offset(0, 16),
    this.axis = Axis.vertical,
  });

  final List<Widget> children;
  final Duration staggerDelay;
  final Duration duration;
  final Offset slideOffset;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final wrapped = children.asMap().entries.map((entry) {
      return AnimatedEntrance(
        index: entry.key,
        staggerDelay: staggerDelay,
        duration: duration,
        slideOffset: slideOffset,
        child: entry.value,
      );
    }).toList();

    if (axis == Axis.horizontal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: wrapped,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: wrapped,
    );
  }
}
