import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/chat/widgets/recommendation_feedback_sheet.dart';

void main() {
  testWidgets('选推荐不准+补充说明，提交返回正确结果', (tester) async {
    (String, String?)? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showRecommendationFeedbackSheet(
                    context: context,
                    professorName: '张三',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('推荐不准'));
    await tester.enterText(find.byType(TextField), '方向对不上');
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();
    expect(result?.$1, '推荐不准');
    expect(result?.$2, '方向对不上');
  });

  testWidgets('未选理由时提交按钮禁用', (tester) async {
    (String, String?)? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showRecommendationFeedbackSheet(
                    context: context,
                    professorName: '张三',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull);
    expect(result, isNull);
  });

  testWidgets('点信息不准确单独提交，note 为空', (tester) async {
    (String, String?)? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showRecommendationFeedbackSheet(
                    context: context,
                    professorName: '张三',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('信息不准确'));
    await tester.pump();
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();
    expect(result?.$1, '信息不准确');
    expect(result?.$2, isNull);
  });
}
