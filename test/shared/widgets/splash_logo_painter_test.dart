import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/splash_logo_painter.dart';

void main() {
  // 用一个记录调用的 mock Canvas 验证 progress=0 时不画帆叶/航向线。
  test('progress=0 时帆叶与航向线均不绘制', () {
    final recorder = _RecordingCanvas();
    final painter = SplashLogoPainter(progress: 0);
    painter.paint(recorder, const Size.square(64));
    expect(recorder.drawPathCount, 0, reason: 'progress=0 时帆叶不应绘制');
    expect(recorder.drawLineCount, 0, reason: 'progress=0 时航向线不应绘制');
  });

  test('progress=1 时帆叶与航向线各绘制一次', () {
    final recorder = _RecordingCanvas();
    final painter = SplashLogoPainter(progress: 1);
    painter.paint(recorder, const Size.square(64));
    expect(
      recorder.drawPathCount,
      greaterThanOrEqualTo(1),
      reason: 'progress=1 时帆叶应绘制',
    );
    expect(recorder.drawLineCount, 1, reason: 'progress=1 时航向线应绘制一次');
  });

  test('progress 增大时帆叶子路径长度递增', () {
    double len(double p) {
      final r = _RecordingCanvas();
      SplashLogoPainter(progress: p).paint(r, const Size.square(64));
      return r.lastLeafPathLength;
    }

    final l1 = len(0.30);
    final l2 = len(0.50);
    final l3 = len(0.70);
    expect(l2, greaterThan(l1), reason: 'progress 0.30→0.50 帆叶应生长');
    expect(l3, greaterThan(l2), reason: 'progress 0.50→0.70 帆叶应生长');
  });

  test('shouldRepaint 仅在 progress 变化时为 true', () {
    final a = SplashLogoPainter(progress: 0.3);
    expect(a.shouldRepaint(SplashLogoPainter(progress: 0.3)), isFalse);
    expect(a.shouldRepaint(SplashLogoPainter(progress: 0.5)), isTrue);
  });
}

class _RecordingCanvas implements Canvas {
  int drawPathCount = 0;
  int drawLineCount = 0;
  double lastLeafPathLength = 0;

  @override
  void drawPath(Path path, Paint paint) {
    drawPathCount++;
    final metrics = path.computeMetrics();
    lastLeafPathLength = metrics.fold<double>(0.0, (acc, m) => acc + m.length);
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => drawLineCount++;

  // ── 以下为 Canvas 接口的 no-op 实现，仅为编译 ──
  @override
  void noSuchMethod(Invocation invocation) {}
}
