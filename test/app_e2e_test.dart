import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/app.dart';

void main() {
  testWidgets('input -> recommend -> open detail (mock data)', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SchoNaviApp()));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '我想找医学影像和计算机视觉方向的导师，最好在上海');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '开始推荐'));
    await tester.pumpAndSettle();

    expect(find.text('推荐结果'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);

    await tester.tap(find.text('张三').first);
    await tester.pumpAndSettle();
    expect(find.text('导师详情'), findsOneWidget);
    expect(find.text('研究方向'), findsOneWidget);
  });
}
