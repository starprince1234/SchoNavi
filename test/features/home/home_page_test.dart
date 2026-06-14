import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/home/pages/home_page.dart';

Future<Widget> _wrap() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/recommendation',
        builder: (_, _) => const Text('mentor-marker'),
      ),
      GoRoute(
        path: '/competition-recommendation',
        builder: (_, _) => const Text('competition-marker'),
      ),
      GoRoute(path: '/profile/wizard', builder: (_, _) => const Text('wizard')),
      GoRoute(path: '/profile', builder: (_, _) => const Text('profile')),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('submit button disabled when input empty', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();
    final button = tester.widget<InkWell>(
      find.ancestor(
        of: find.byIcon(Icons.arrow_upward),
        matching: find.byType(InkWell),
      ),
    );
    expect(button.onTap, isNull);
  });

  testWidgets('submit button enabled after typing', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '我想找医学影像方向的导师');
    await tester.pump();
    final button = tester.widget<InkWell>(
      find.ancestor(
        of: find.byIcon(Icons.arrow_upward),
        matching: find.byType(InkWell),
      ),
    );
    expect(button.onTap, isNotNull);
  });

  testWidgets('example prompt fills the input', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    final example = find.text('我想找计算机视觉方向的导师，最好在北京。');
    await tester.scrollUntilVisible(
      example,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(example);
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.controller?.text, '我想找计算机视觉方向的导师，最好在北京。');
  });

  testWidgets('competition prompt routes to competition recommendation', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('竞赛推荐'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '我想参加蓝桥杯');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(find.text('competition-marker'), findsOneWidget);
  });

  testWidgets('mentor prompt still routes to mentor recommendation', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '我想找医学影像方向的导师');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(find.text('mentor-marker'), findsOneWidget);
  });

  testWidgets('competition quick tag routes to competition recommendation', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('竞赛推荐'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('人工智能竞赛'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(find.text('competition-marker'), findsOneWidget);
  });

  testWidgets('right edge swipe opens the end drawer', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(Scaffold));
    await tester.flingFrom(
      Offset(size.width - 10, 200),
      const Offset(-200, 0),
      800,
    );
    await tester.pumpAndSettle();

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    expect(scaffoldState.isEndDrawerOpen, isTrue);
  });

  testWidgets('switching tab shows competition examples and tags', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('竞赛推荐'));
    await tester.pumpAndSettle();

    expect(
      find.text('推荐近期可报名的人工智能竞赛。'),
      findsOneWidget,
    );
    expect(find.text('人工智能竞赛'), findsOneWidget);
  });

  testWidgets('switching tab preserves input text', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '保留输入');
    await tester.pump();

    await tester.tap(find.text('竞赛推荐'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('导师推荐'));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.controller?.text, '保留输入');
  });
}
