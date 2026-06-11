import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/features/home/pages/home_page.dart';

Widget _wrap() {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/recommendation', builder: (_, _) => const Placeholder()),
      GoRoute(path: '/profile/wizard', builder: (_, _) => const Text('wizard')),
      GoRoute(path: '/profile', builder: (_, _) => const Text('profile')),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('submit button disabled when input empty', (tester) async {
    await tester.pumpWidget(_wrap());
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始推荐'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('submit button enabled after typing', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(find.byType(TextField), '我想找医学影像方向的导师');
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始推荐'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('example prompt fills the input', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('我想找计算机视觉方向的导师，最好在北京。'));
    await tester.pump();
    expect(
      find.widgetWithText(TextField, '我想找计算机视觉方向的导师，最好在北京。'),
      findsOneWidget,
    );
  });
}
