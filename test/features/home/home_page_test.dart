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
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  testWidgets('submit button disabled when input empty', (tester) async {
    await tester.pumpWidget(_wrap());
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
    await tester.pumpWidget(_wrap());
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
    await tester.pumpWidget(_wrap());
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

  testWidgets('right edge swipe opens the end drawer', (tester) async {
    await tester.pumpWidget(_wrap());
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
}
