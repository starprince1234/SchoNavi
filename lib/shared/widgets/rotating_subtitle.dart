import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Strategy that owns the full animated presentation of a single phrase.
///
/// Typewriter and fade transitions work fundamentally differently — one
/// reveals a single phrase character by character, the other cross-fades
/// between two phrases — so each strategy renders the phrase itself rather
/// than sharing a single [AnimatedSwitcher.transitionBuilder].
abstract interface class SubtitleAnimationStrategy {
  /// Builds the animated widget showing [text]. When [text] changes, the
  /// strategy decides how to transition to it.
  Widget build(BuildContext context, String text, TextStyle? style);

  /// How long [text] should stay on screen before the rotation advances.
  Duration holdDurationFor(String text);
}

/// Old phrase slides up and fades out; the new phrase rises in from below.
class FadeSlideStrategy implements SubtitleAnimationStrategy {
  const FadeSlideStrategy();

  @override
  Duration holdDurationFor(String text) => const Duration(seconds: 3);

  @override
  Widget build(BuildContext context, String text, TextStyle? style) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Text(
        text,
        key: ValueKey<String>(text),
        style: style,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Pure opacity cross-fade between phrases.
class CrossfadeStrategy implements SubtitleAnimationStrategy {
  const CrossfadeStrategy();

  @override
  Duration holdDurationFor(String text) => const Duration(seconds: 3);

  @override
  Widget build(BuildContext context, String text, TextStyle? style) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Text(
        text,
        key: ValueKey<String>(text),
        style: style,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Types the phrase out one grapheme at a time with a trailing caret.
class TypewriterStrategy implements SubtitleAnimationStrategy {
  const TypewriterStrategy({
    this.perCharacter = const Duration(milliseconds: 90),
    this.holdAfterTyped = const Duration(milliseconds: 1800),
  });

  final Duration perCharacter;
  final Duration holdAfterTyped;

  @override
  Duration holdDurationFor(String text) =>
      perCharacter * text.characters.length + holdAfterTyped;

  @override
  Widget build(BuildContext context, String text, TextStyle? style) {
    return _TypewriterText(
      text: text,
      style: style,
      perCharacter: perCharacter,
    );
  }
}

/// A rotating subtitle that cycles through [phrases], delegating the per-phrase
/// animation to [strategy]. Respects reduced-motion: when animations are
/// disabled it shows the first phrase statically.
class RotatingSubtitle extends StatefulWidget {
  const RotatingSubtitle({
    super.key,
    required this.phrases,
    required this.strategy,
    this.style,
  });

  final List<String> phrases;
  final SubtitleAnimationStrategy strategy;
  final TextStyle? style;

  @override
  State<RotatingSubtitle> createState() => _RotatingSubtitleState();
}

class _RotatingSubtitleState extends State<RotatingSubtitle> {
  int _index = 0;
  Timer? _timer;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _restart();
  }

  @override
  void didUpdateWidget(RotatingSubtitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.phrases, widget.phrases)) {
      _index = 0;
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    if (_reduceMotion || widget.phrases.length <= 1) return;
    _scheduleNext();
  }

  void _scheduleNext() {
    if (widget.phrases.isEmpty) return;
    final current = widget.phrases[_index];
    _timer = Timer(widget.strategy.holdDurationFor(current), () {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.phrases.length);
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.phrases.isEmpty ? '' : widget.phrases[_index];
    if (_reduceMotion) {
      return Text(text, style: widget.style, textAlign: TextAlign.center);
    }
    return widget.strategy.build(context, text, widget.style);
  }
}

class _TypewriterText extends StatefulWidget {
  const _TypewriterText({
    required this.text,
    required this.style,
    required this.perCharacter,
  });

  final String text;
  final TextStyle? style;
  final Duration perCharacter;

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  Timer? _timer;
  int _chars = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _start();
  }

  void _start() {
    _timer?.cancel();
    _chars = 0;
    _timer = Timer.periodic(widget.perCharacter, (timer) {
      if (!mounted) return;
      if (_chars >= widget.text.characters.length) {
        timer.cancel();
        return;
      }
      setState(() => _chars++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.text.characters.length;
    final shown = widget.text.characters.take(_chars).toString();
    final done = _chars >= total;
    return Text.rich(
      TextSpan(
        text: shown,
        children: [
          if (!done)
            const TextSpan(
              text: '▏',
              style: TextStyle(color: AppColors.indigo),
            ),
        ],
      ),
      style: widget.style,
      textAlign: TextAlign.center,
    );
  }
}
