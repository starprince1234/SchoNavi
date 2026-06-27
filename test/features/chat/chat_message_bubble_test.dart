import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/favorite_item.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/repositories/favorite_repository.dart';
import 'package:scho_navi/features/chat/widgets/chat_message_bubble.dart';
import 'package:scho_navi/shared/widgets/swipe_recommendation_card.dart';
import 'package:scho_navi/shared/widgets/thinking_indicator.dart';

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

class _FakeFavoriteRepo implements FavoriteRepository {
  final _items = <String, FavoriteItem>{};
  final _controller = StreamController<List<FavoriteItem>>.broadcast();
  @override
  List<FavoriteItem> list() => _items.values.toList();
  @override
  Stream<List<FavoriteItem>> watch() => _controller.stream;
  @override
  bool isFavorite(String professorId) => _items.containsKey(professorId);
  @override
  Future<void> add(FavoriteItem item) async {
    _items[item.professorId] = item;
    _controller.add(list());
  }

  @override
  Future<void> remove(String professorId) async {
    _items.remove(professorId);
    _controller.add(list());
  }

  @override
  Future<bool> toggle(FavoriteItem item) async {
    if (_items.containsKey(item.professorId)) {
      await remove(item.professorId);
      return false;
    }
    await add(item);
    return true;
  }
}

ChatMessage _msg({
  required ChatRole role,
  required String content,
  required ChatMessageStatus status,
  ChatMessageKind kind = ChatMessageKind.conversation,
  List<Recommendation> related = const [],
}) => ChatMessage(
  id: 'm_0',
  role: role,
  content: content,
  createdAt: DateTime(2026, 6, 9),
  relatedRecommendations: related,
  status: status,
  kind: kind,
);

Future<void> _pump(
  WidgetTester tester,
  ChatMessage message, {
  void Function(String)? onTap,
  void Function(String)? onRetryRecommendation,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        favoriteRepositoryProvider.overrideWithValue(_FakeFavoriteRepo()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            message: message,
            onTapRecommendation: onTap ?? (_) {},
            onRetryRecommendation: onRetryRecommendation,
          ),
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

    expect(find.byType(ThinkingIndicator), findsOneWidget);
    expect(find.text('正在思考'), findsOneWidget);
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

    expect(find.byType(SwipeRecommendationCard), findsOneWidget);
    await tester.tap(find.byType(SwipeRecommendationCard));
    expect(tapped, 'p_001');
  });

  testWidgets('流式中（有文本）显示 Markdown 与生成中指示', (tester) async {
    await _pump(
      tester,
      _msg(
        role: ChatRole.assistant,
        content: '正在生成的**部分**',
        status: ChatMessageStatus.streaming,
      ),
    );

    expect(find.byType(GptMarkdown), findsOneWidget);
    expect(find.text('生成中…'), findsOneWidget);
  });

  testWidgets('流式中（空文本）显示正在思考', (tester) async {
    await _pump(
      tester,
      _msg(
        role: ChatRole.assistant,
        content: '',
        status: ChatMessageStatus.streaming,
      ),
    );

    expect(find.byType(ThinkingIndicator), findsOneWidget);
    expect(find.text('正在思考'), findsOneWidget);
  });

  testWidgets('推荐失败显示重试按钮且不显示重新生成操作', (tester) async {
    String? retried;
    await _pump(
      tester,
      _msg(
        role: ChatRole.assistant,
        content: '服务异常，请稍后重试',
        status: ChatMessageStatus.error,
        kind: ChatMessageKind.recommendation,
      ),
      onRetryRecommendation: (id) => retried = id,
    );

    expect(find.text('重试推荐'), findsOneWidget);
    expect(find.byTooltip('重新生成'), findsNothing);
    await tester.tap(find.text('重试推荐'));
    expect(retried, 'm_0');
  });
}
