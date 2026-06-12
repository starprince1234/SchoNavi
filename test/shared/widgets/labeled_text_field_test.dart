import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/labeled_text_field.dart';

void main() {
  testWidgets('显示 label 与初值，输入触发 onChanged', (tester) async {
    String? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LabeledTextField(
            label: '姓名',
            initialValue: '张三',
            onChanged: (v) => changed = v,
          ),
        ),
      ),
    );

    expect(find.text('姓名'), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '李四');
    expect(changed, '李四');
  });
}
