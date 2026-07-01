import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/theme/app_colors.dart';
import 'package:scho_navi/shared/widgets/thinking_indicator.dart';

void main() {
  testWidgets('渲染 svg 图标与「正在思考」文案 + 三个品牌渐变方形点', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ThinkingIndicator())),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('正在思考'), findsOneWidget);
    expect(find.text('正在思考…'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // 三个方形点（句号样式，非圆点），用 ValueKey<int>(0/1/2) 定位。
    for (var i = 0; i < 3; i++) {
      final dot = find.byKey(ValueKey<int>(i));
      expect(dot, findsOneWidget, reason: '第 $i 个点应存在（ValueKey<int>($i)）');
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: dot, matching: find.byType(DecoratedBox)).first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(
        decoration.shape,
        BoxShape.rectangle,
        reason: '点 $i 应为方形（句号样式，非圆点）',
      );
      expect(
        decoration.gradient,
        AppColors.brandGradient,
        reason: '点 $i 应染品牌渐变',
      );
      // 尺寸精简为 3×3。
      expect(tester.getSize(dot), const Size(3, 3), reason: '点 $i 应为 3×3（精简）');
    }

    // 点应像句号贴在文案底部（底部对齐），而非垂直居中。
    final textRect = tester.getRect(find.text('正在思考'));
    final dot0Rect = tester.getRect(find.byKey(const ValueKey<int>(0)));
    expect(
      dot0Rect.bottom,
      closeTo(textRect.bottom, 0.5),
      reason: '点应与文案底部对齐（句号样式，不居中）',
    );
  });

  testWidgets('「正在思考」文案染品牌渐变且有亮纹扫过（与图标一致）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ThinkingIndicator())),
    );

    final text = find.text('正在思考');
    expect(text, findsOneWidget);

    // 文案必须被 ShaderMask（品牌渐变 srcIn）包裹 —— 渐变填充。
    final shaderMask = tester.widget<ShaderMask>(
      find.ancestor(of: text, matching: find.byType(ShaderMask)).first,
    );
    expect(shaderMask.blendMode, BlendMode.srcIn, reason: '文案应被 srcIn 染品牌渐变');

    // 文案上方必须有 CustomPaint(foregroundPainter) 叠加亮纹扫过。
    final customPaints = find
        .ancestor(of: text, matching: find.byType(CustomPaint))
        .evaluate();
    final hasForegroundPainter = customPaints.any((element) {
      final cp = element.widget;
      return cp is CustomPaint && cp.foregroundPainter != null;
    });
    expect(
      hasForegroundPainter,
      isTrue,
      reason: '文案上方应有 CustomPaint.foregroundPainter 绘制移动亮纹',
    );
  });

  testWidgets('三点错峰上下跳跃（波浪式）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ThinkingIndicator())),
    );

    // 起始帧 v=0：t = (0*2 + i*0.2) % 1 → i=0,1,2 → 0/0.2/0.4 全 ≤0.6 活跃，
    // 但 sin(0)=0、sin(0.2π/0.6)=sin(π/3)≠0、sin(0.4π/0.6)=sin(2π/3)≠0。
    // controller repeat 起点为 0；先 pump 一帧让首帧布局完成。
    await tester.pump();

    // pump 到 v≈0.15（300ms / 2000ms）。此时 i=0: t=0.3 活跃段,
    // u=0.5, dy=-sin(0.5π)*3=-3。非零 → 证明在跳。
    await tester.pump(const Duration(milliseconds: 300));

    final dy0 = _dotDy(tester, 0);
    expect(dy0, isNot(equals(0.0)), reason: 'v≈0.15 时 i=0 应处于活跃段，dy 非零（约 -3）');

    // 三点错峰：同一时刻 i=0 与 i=2 相位不同 → dy 不同。
    final dy2 = _dotDy(tester, 2);
    expect(dy0, isNot(equals(dy2)), reason: '错峰 0.2 应使相邻点 dy 不同');
  });

  testWidgets('动画 repeat 不阻塞 pump，dispose 后无异常', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ThinkingIndicator())),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}

/// 读取第 i 个圆点 Transform.translate 的 vertical offset。
double _dotDy(WidgetTester tester, int i) {
  final dot = find.byKey(ValueKey<int>(i));
  final transform = tester.widget<Transform>(
    find.ancestor(of: dot, matching: find.byType(Transform)).first,
  );
  return transform.transform.getTranslation().y;
}
