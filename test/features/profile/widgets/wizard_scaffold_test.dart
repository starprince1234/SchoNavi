import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/profile/widgets/wizard_scaffold.dart';

void main() {
  testWidgets('显示标题与下一步；点下一步回调', (tester) async {
    var next = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WizardScaffold(
          title: '基本信息',
          index: 0,
          count: 3,
          nextLabel: '下一步',
          onNext: () => next = true,
          child: const Text('body'),
        ),
      ),
    );
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
    await tester.tap(find.text('下一步'));
    expect(next, isTrue);
  });
}
