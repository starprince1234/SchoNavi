import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/onboarding/pages/onboarding_page.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _app(ProviderContainer container) {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(path: '/home', builder: (_, _) => const Text('home-marker')),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('点「跳过」写 seenOnboarding 并跳首页', (tester) async {
    final container = await _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();

    expect(find.text('home-marker'), findsOneWidget);
    expect(
      container.read(localStoreProvider).getBool(OnboardingPage.seenKey),
      isTrue,
    );
  });

  testWidgets('滑到末页「开始使用」写标记并跳首页', (tester) async {
    final container = await _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('下一步'), findsOneWidget);
    // 拖到末页（3 页 → 拖 2 次）
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('开始使用'), findsOneWidget);
    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();

    expect(find.text('home-marker'), findsOneWidget);
    expect(
      container.read(localStoreProvider).getBool(OnboardingPage.seenKey),
      isTrue,
    );
  });
}
