import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/thinking_indicator.dart';

void main() {
  testWidgets('渲染 svg 图标与「正在思考…」文案，不渲染旧转圈', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ThinkingIndicator()),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('正在思考…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('动画 repeat 不阻塞 pump，dispose 后无异常', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ThinkingIndicator()),
      ),
    );
    // 不能用 pumpAndSettle（repeat 永不完成）；pump 固定时长验证不抛错。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // 重新挂载一次，验证上一次 dispose 释放 controller 无异常。
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox.shrink()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
