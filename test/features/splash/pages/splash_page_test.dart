import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/features/splash/pages/splash_page.dart';
import 'package:scho_navi/features/splash/splash_controller.dart';

Widget _wrapWith(
  ProviderContainer container, {
  bool readyToExit = false,
  VoidCallback? onFinished,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: SplashPage(
        readyToExit: readyToExit,
        onFinished: onFinished ?? () {},
      ),
    ),
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
    await tester.pumpWidget(_wrapWith(container));
    await tester.pump();
    expect(container.read(splashControllerProvider).isCompleted, isFalse);

    await tester.tap(find.byType(SplashPage));
    await tester.pump();
    expect(container.read(splashControllerProvider).isCompleted, isTrue);
    expect(find.byType(SplashPage), findsOneWidget);
  });

  testWidgets('动画先完成时停留最终帧，初始化就绪后才淡出', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var finished = 0;

    await tester.pumpWidget(_wrapWith(container, onFinished: () => finished++));
    container.read(splashControllerProvider.notifier).skip();
    await tester.pump();

    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    expect(finished, 0);

    await tester.pumpWidget(
      _wrapWith(container, readyToExit: true, onFinished: () => finished++),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(finished, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(finished, 1);
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
    expect(find.bySemanticsLabel('跳过开屏动画'), findsOneWidget);
  });
}
