import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/features/splash/pages/splash_page.dart';
import 'package:scho_navi/features/splash/splash_controller.dart';

Widget _wrapWith(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: SplashPage()),
  );
}

void main() {
  testWidgets('初始渲染：logo CustomPaint + 「SchoNavi」字标存在', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(_wrapWith(container));
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('SchoNavi'), findsOneWidget);
  });

  testWidgets('点按跳过 → isCompleted=true', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SplashPage()),
      ),
    );
    await tester.pump();
    expect(container.read(splashControllerProvider).isCompleted, isFalse);

    await tester.tap(find.byType(SplashPage));
    await tester.pump();
    expect(container.read(splashControllerProvider).isCompleted, isTrue);
  });

  testWidgets('整页可点按（GestureDetector 存在）', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(_wrapWith(container));
    await tester.pump();
    expect(
      find.ancestor(
        of: find.byType(AnimatedOpacity),
        matching: find.byType(GestureDetector),
      ),
      findsOneWidget,
    );
  });
}
