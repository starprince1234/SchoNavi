import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/labeled_text_field.dart';

void main() {
  testWidgets('无 errorText 时正常渲染', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LabeledTextField(label: '字段', onChanged: _noop),
        ),
      ),
    );
    expect(find.text('字段'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('errorText 非空时显示错误文本', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LabeledTextField(
            label: '字段',
            onChanged: _noop,
            errorText: '不能为空',
          ),
        ),
      ),
    );
    expect(find.text('不能为空'), findsOneWidget);
  });

  testWidgets('输入触发 onChanged', (tester) async {
    String? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LabeledTextField(label: '字段', onChanged: (v) => captured = v),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'hello');
    expect(captured, 'hello');
  });
}

void _noop(String _) {}
