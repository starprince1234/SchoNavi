import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  testWidgets('gpt_markdown 可用：能渲染 markdown 且不抛异常', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GptMarkdown('你好 **世界**，这是 `inline code` 与一段列表：\n- A\n- B'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 核心断言：包能解析+构建渲染树而不报错。
    expect(tester.takeException(), isNull);
    expect(find.byType(GptMarkdown), findsOneWidget);
    // 次要断言：原始 markdown 标记不应作为整段字面文本出现。
    expect(find.text('你好 **世界**，这是 `inline code` 与一段列表：\n- A\n- B'),
        findsNothing);
  });
}
