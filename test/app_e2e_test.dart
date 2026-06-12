import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/app.dart';
import 'package:scho_navi/core/di/providers.dart';

Future<ProviderScope> _wrap() async {
  SharedPreferences.setMockInitialValues(
    <String, Object>{
      'seenOnboarding': true,
      'profile_prompt_dismissed': true,
    },
  );
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const SchoNaviApp(),
  );
}

void main() {
  testWidgets('input -> recommend -> favorite -> detail -> favorites/history', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '我想找医学影像和计算机视觉方向的导师，最好在上海');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(find.text('推荐结果'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);

    await tester.tap(find.byTooltip('收藏导师').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('取消收藏'), findsOneWidget);

    await tester.tap(find.text('张三').first);
    await tester.pumpAndSettle();
    expect(find.text('导师详情'), findsOneWidget);
    expect(find.text('研究方向'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('收藏').last);
    await tester.pumpAndSettle();
    expect(find.text('张三'), findsOneWidget);

    await tester.tap(find.text('历史').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('医学影像和计算机视觉'), findsOneWidget);
  });
}
