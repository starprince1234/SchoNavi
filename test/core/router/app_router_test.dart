import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/app.dart';
import 'package:scho_navi/core/di/providers.dart';

Future<Widget> _wrap() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const SchoNaviApp(),
  );
}

void main() {
  testWidgets('bottom navigation switches between home favorites and history', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    expect(find.text('用自然语言找到适合你的导师'), findsOneWidget);

    await tester.tap(find.text('收藏').last);
    await tester.pumpAndSettle();
    expect(find.text('还没有收藏导师'), findsOneWidget);

    await tester.tap(find.text('历史').last);
    await tester.pumpAndSettle();
    expect(find.text('暂无搜索历史'), findsOneWidget);

    await tester.tap(find.text('首页').last);
    await tester.pumpAndSettle();
    expect(find.text('用自然语言找到适合你的导师'), findsOneWidget);
  });
}
