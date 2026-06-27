import 'package:flutter/animation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Splash 动画状态：[progress] 0.0→1.0 驱动 painter，[isCompleted] 触发 fade-out。
class SplashState {
  const SplashState({this.progress = 0.0, this.isCompleted = false});

  final double progress;
  final bool isCompleted;

  SplashState copyWith({double? progress, bool? isCompleted}) => SplashState(
        progress: progress ?? this.progress,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}

/// Splash 动画状态容器与命令入口。
///
/// Ticker 由 [SplashPage]（SingleTickerProviderStateMixin）创建并通过
/// [attach] 注入引用；页面监听 Ticker 把 value 推给 [setProgress]，到 1.0
/// 自动完成。页面调 [skip] 跳过、[markNavigated] 停 Ticker 防导航后残余帧。
///
/// 设计：Notifier 无 vsync 故不自建 Ticker，但持其引用使 skip/markNavigated
/// 落实为真实行为；纯逻辑单测无需真 Ticker 即可覆盖状态机。
class SplashController extends Notifier<SplashState> {
  AnimationController? _ticker;
  VoidCallback? _tickerListener;
  bool _navigated = false;

  @override
  SplashState build() {
    ref.onDispose(_detachTicker);
    return const SplashState();
  }

  /// 移除 ticker 监听并清空引用，防泄漏与重复 attach。
  void _detachTicker() {
    if (_tickerListener != null && _ticker != null) {
      _ticker!.removeListener(_tickerListener!);
    }
    _ticker = null;
    _tickerListener = null;
  }

  /// 页面在 initState 创建 Ticker 后调用：保存引用并挂监听，
  /// Ticker 每帧把 value 推给 [setProgress]。
  void attach(AnimationController ticker) {
    // 防重复 attach：先移除旧 listener。
    _detachTicker();
    _ticker = ticker;
    _tickerListener = () => setProgress(ticker.value);
    ticker.addListener(_tickerListener!);
  }

  /// 由 Ticker listener 推送当前进度值（0.0-1.0）。
  void setProgress(double value) {
    if (_navigated) return; // 导航后忽略残余帧
    if (value >= 1.0) {
      state = const SplashState(progress: 1.0, isCompleted: true);
      return;
    }
    state = SplashState(progress: value, isCompleted: false);
  }

  /// 跳过动画：把 Ticker 跳到 1.0（listener 触发 setProgress(1.0)→完成）；
  /// 无 Ticker 引用时兜底直接置完成态。
  void skip() {
    final t = _ticker;
    if (t != null && t.value < 1.0) {
      t.value = 1.0;
    } else {
      state = const SplashState(progress: 1.0, isCompleted: true);
    }
  }

  /// 页面完成 fade-out 导航后调用：停 Ticker、后续 setProgress 被忽略。
  void markNavigated() {
    _navigated = true;
    _ticker?.stop();
  }
}

final splashControllerProvider =
    NotifierProvider<SplashController, SplashState>(SplashController.new);
