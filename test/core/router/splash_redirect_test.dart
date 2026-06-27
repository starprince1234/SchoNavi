import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/router/app_router.dart';
import 'package:scho_navi/features/onboarding/pages/onboarding_page.dart';
import 'package:scho_navi/features/splash/pages/splash_page.dart';

Future<Widget> _app(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('冷启动从 /splash 开始，动画播完后未读引导 → 重定向到 /onboarding', (tester) async {
    await tester.pumpWidget(await _app(<String, Object>{}));
    await tester.pump(); // 首帧：停在 SplashPage
    expect(find.byType(SplashPage), findsOneWidget);

    // 跑完 1.8s 动画 + 200ms fade-out。
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('已读引导 → 动画播完后停在首页（不显示 onboarding）', (tester) async {
    await tester.pumpWidget(await _app(<String, Object>{'seenOnboarding': true}));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(OnboardingPage), findsNothing);
  });

  testWidgets('initialLocation 为 /splash', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'seenOnboarding': true});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    expect(router.routeInformationProvider.value.uri.toString(), '/splash');
  });
}
