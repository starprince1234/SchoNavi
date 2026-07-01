import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/step_dots.dart';

void main() {
  testWidgets('渲染 count 个圆点', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StepDots(count: 3, index: 1))),
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is AnimatedContainer &&
            (w.key as ValueKey?)?.value == 'step-dot-0',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is AnimatedContainer &&
            (w.key as ValueKey?)?.value == 'step-dot-1',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is AnimatedContainer &&
            (w.key as ValueKey?)?.value == 'step-dot-2',
      ),
      findsOneWidget,
    );
  });
}
