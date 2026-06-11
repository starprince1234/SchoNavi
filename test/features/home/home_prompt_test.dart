import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/home/pages/home_page.dart';

Future<ProviderContainer> _c() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('空档案首次提交弹出完善档案 sheet', (tester) async {
    final c = await _c();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomePage()),
        GoRoute(path: '/profile/wizard', builder: (_, _) => const Text('wizard')),
        GoRoute(path: '/recommendation', builder: (_, _) => const Text('reco')),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '我想找计算机视觉方向导师');
    await tester.tap(find.text('开始推荐'));
    await tester.pumpAndSettle();

    expect(find.text('完善档案，推荐更准'), findsOneWidget);
  });
}
