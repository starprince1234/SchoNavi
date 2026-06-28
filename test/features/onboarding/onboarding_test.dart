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
  testWidgets('展示面向新用户的三页开屏文案', (tester) async {
    final container = await _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('说出你的方向'), findsOneWidget);
    expect(find.text('输入研究兴趣、目标院校或想申请的专业，SchoNavi 帮你快速找到合适的导师线索。'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('把申请理清楚'), findsOneWidget);
    expect(find.text('查看推荐理由、继续追问细节，还能生成套磁思路、对比多位导师，少走弯路。'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('推荐更有依据'), findsOneWidget);
    expect(find.text('信息来自可查资料，帮你看清导师方向、匹配程度和下一步该怎么准备。'), findsOneWidget);
  });

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
