import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/completion_ring.dart';

void main() {
  testWidgets('显示百分比文案', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CompletionRing(value: 0.86))),
    );
    await tester.pumpAndSettle();
    expect(find.text('86%'), findsOneWidget);
  });
}
