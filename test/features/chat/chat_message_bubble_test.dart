import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/features/chat/widgets/chat_message_bubble.dart';
import 'package:scho_navi/shared/widgets/professor_card.dart';

const _rec = Recommendation(
  professorId: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像', '计算机视觉'],
  matchLevel: MatchLevel.high,
  reason: '方向相关。',
  limitations: [],
);

ChatMessage _msg({
  required ChatRole role,
  required String content,
  required ChatMessageStatus status,
  List<Recommendation> related = const [],
}) => ChatMessage(
  id: 'm_0',
  role: role,
  content: content,
  createdAt: DateTime(2026, 6, 9),
  relatedRecommendations: related,
  status: status,
);

Future<void> _pump(
  WidgetTester tester,
  ChatMessage message, {
  void Function(String)? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChatMessageBubble(
          message: message,
          onTapRecommendation: onTap ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('用户消息用纯文本、无 Markdown', (tester) async {
    await _pump(
      tester,
      _msg(
        role: ChatRole.user,
        content: '为什么推荐他',
        status: ChatMessageStatus.done,
      ),
    );

    expect(find.text('为什么推荐他'), findsOneWidget);
    expect(find.byType(GptMarkdown), findsNothing);
  });

  testWidgets('助手消息用 Markdown 渲染', (tester) async {
    await _pump(
      tester,
      _msg(
        role: ChatRole.assistant,
        content: '**加粗** 回答',
        status: ChatMessageStatus.done,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GptMarkdown), findsOneWidget);
  });

  testWidgets('思考中显示进度指示与文案', (tester) async {
    await _pump(
      tester,
      _msg(
        role: ChatRole.assistant,
        content: '',
        status: ChatMessageStatus.sending,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('正在思考…'), findsOneWidget);
  });

  testWidgets('错误消息用纯文本展示文案', (tester) async {
    await _pump(
      tester,
      _msg(
        role: ChatRole.assistant,
        content: '服务异常，请稍后重试',
        status: ChatMessageStatus.error,
      ),
    );

    expect(find.text('服务异常，请稍后重试'), findsOneWidget);
    expect(find.byType(GptMarkdown), findsNothing);
  });

  testWidgets('嵌入推荐卡片可点击回调', (tester) async {
    String? tapped;
    await _pump(
      tester,
      _msg(
        role: ChatRole.assistant,
        content: '相近导师如下',
        status: ChatMessageStatus.done,
        related: const [_rec],
      ),
      onTap: (id) => tapped = id,
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfessorCard), findsOneWidget);
    await tester.tap(find.byType(ProfessorCard));
    expect(tapped, 'p_001');
  });
}
