import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/chat/widgets/inline_dislike_feedback.dart';

void main() {
  testWidgets('提交时回调传入 trim 后文本', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineDislikeFeedback(
            onSubmit: (text) => submitted = text,
            onCollapse: () {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '  说得不清楚  ');
    await tester.tap(find.text('提交'));
    expect(submitted, '说得不清楚');
  });

  testWidgets('收起触发 onCollapse', (tester) async {
    var collapsed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineDislikeFeedback(
            onSubmit: (_) {},
            onCollapse: () => collapsed = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('收起'));
    expect(collapsed, isTrue);
  });

  testWidgets('submitting 时提交按钮禁用并显示加载', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineDislikeFeedback(
            onSubmit: (_) {},
            onCollapse: () {},
            submitting: true,
          ),
        ),
      ),
    );
    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
