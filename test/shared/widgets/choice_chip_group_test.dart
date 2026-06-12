import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/choice_chip_group.dart';

void main() {
  testWidgets('点选某项回调其值', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChoiceChipGroup<String>(
            options: const [('m', '男'), ('f', '女')],
            selected: 'm',
            onSelected: (v) => picked = v,
          ),
        ),
      ),
    );

    expect(find.text('男'), findsOneWidget);
    await tester.tap(find.text('女'));
    expect(picked, 'f');
  });
}
