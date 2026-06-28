import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/cool_scaffold_background.dart';
import '../../../shared/widgets/splash_logo_painter.dart';
import '../splash_controller.dart';

/// 开屏品牌动画页：2.0s logo 绘制叙事 + 字标入场，可点按跳过，
/// 动画完成后停留在最终品牌帧；仅当 [readyToExit] 同时为 true 时整页
/// fade out（200ms），随后通过 [onFinished] 把控制权交给应用启动协调层。
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({
    super.key,
    required this.readyToExit,
    required this.onFinished,
  });

  final bool readyToExit;
  final VoidCallback onFinished;

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  late final SplashController _controller;
  bool _finished = false;
  bool _reducedMotionApplied = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(splashControllerProvider.notifier);
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    // Ticker 由页面提供 vsync，控制器通过 attach 挂监听把 value 推给 setProgress。
    _controller.attach(_ticker);
    _ticker.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion && !_reducedMotionApplied) {
      _reducedMotionApplied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.skip();
      });
    }
  }

  @override
  void dispose() {
    // dispose 中 ref 不可用，提前缓存 controller 引用。
    _controller.detach();
    _ticker.dispose();
    super.dispose();
  }

  void _onFadeOutEnd() {
    if (_finished) return;
    _finished = true;
    ref.read(splashControllerProvider.notifier).markNavigated();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(splashControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldExit = state.isCompleted && widget.readyToExit;

    // 字标：opacity + translate-y，interval [0.72, 1.0]。
    final wordmarkT = clampInterval(state.progress, 0.72, 1.0);
    final wordmarkOpacity = wordmarkT;
    final wordmarkDy = (1 - wordmarkT) * 12.0;

    return Semantics(
      button: true,
      label: '跳过开屏动画',
      onTap: ref.read(splashControllerProvider.notifier).skip,
      child: GestureDetector(
        onTap: ref.read(splashControllerProvider.notifier).skip,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: shouldExit ? 0.0 : 1.0,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          onEnd: shouldExit ? _onFadeOutEnd : null,
          child: Stack(
            children: [
              const Positioned.fill(child: CoolScaffoldBackground()),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CustomPaint(
                        size: const Size.square(72),
                        painter: SplashLogoPainter(progress: state.progress),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: wordmarkOpacity,
                      child: Transform.translate(
                        offset: Offset(0, wordmarkDy),
                        child: ShaderMask(
                          shaderCallback: (bounds) =>
                              AppColors.brandGradient.createShader(bounds),
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            'SchoNavi',
                            // srcIn 会用 brandGradient 替换文字颜色，此处不指定颜色。
                            style:
                                (textTheme.headlineMedium ??
                                        const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                        ))
                                    .copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
