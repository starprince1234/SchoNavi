import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/right_edge_open_drawer.dart';

void main() {
  group('RightEdgeOpenDrawer', () {
    Widget build(VoidCallback onSwipe) {
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: RightEdgeOpenDrawer(onSwipe: onSwipe),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('fast leftward swipe from right edge triggers onSwipe', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(build(() => calls++));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(Scaffold));
      await tester.flingFrom(
        Offset(size.width - 10, size.height / 2),
        const Offset(-200, 0),
        800,
      );

      expect(calls, 1);
    });

    testWidgets('slow leftward swipe does not trigger onSwipe', (tester) async {
      var calls = 0;
      await tester.pumpWidget(build(() => calls++));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(Scaffold));
      await tester.dragFrom(
        Offset(size.width - 10, size.height / 2),
        const Offset(-200, 0),
      );
      await tester.pump();

      expect(calls, 0);
    });

    testWidgets('rightward swipe does not trigger onSwipe', (tester) async {
      var calls = 0;
      await tester.pumpWidget(build(() => calls++));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(Scaffold));
      await tester.flingFrom(
        Offset(size.width - 30, size.height / 2),
        const Offset(200, 0),
        800,
      );

      expect(calls, 0);
    });

    testWidgets('swipe outside the right edge strip does not trigger onSwipe', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(build(() => calls++));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(Scaffold));
      await tester.flingFrom(
        Offset(size.width - 60, size.height / 2),
        const Offset(-200, 0),
        800,
      );

      expect(calls, 0);
    });
  });
}
