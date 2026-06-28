// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/swipe_card_carousel.dart';

void main() {
  testWidgets('空列表渲染空', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SwipeCardCarousel<String>(
          items: const [],
          itemBuilder: (_, s, __) => Text(s),
          semanticsLabel: (s) => s,
        ),
      ),
    ));
    expect(find.byType(SwipeCardCarousel<String>), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('3 项渲染 3 张 + 指示器', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: SwipeCardCarousel<String>(
            items: const ['a', 'b', 'c'],
            itemBuilder: (_, s, __) => Text(s),
            semanticsLabel: (s) => s,
          ),
        ),
      ),
    ));
    expect(find.text('a'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(3));
    expect(find.byKey(const Key('carousel-indicator-0')), findsOneWidget);
    expect(find.byKey(const Key('carousel-indicator-1')), findsOneWidget);
    expect(find.byKey(const Key('carousel-indicator-2')), findsOneWidget);
  });

  testWidgets('单张无指示器', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: SwipeCardCarousel<String>(
            items: const ['only'],
            itemBuilder: (_, s, __) => Text(s),
            semanticsLabel: (s) => s,
          ),
        ),
      ),
    ));
    expect(find.text('only'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);
    expect(find.byKey(const Key('carousel-indicator-0')), findsNothing);
  });
}
