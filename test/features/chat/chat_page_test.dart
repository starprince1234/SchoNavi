import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';
import 'package:scho_navi/domain/repositories/chat_repository.dart';
import 'package:scho_navi/features/chat/pages/chat_page.dart';
import 'package:scho_navi/features/chat/widgets/chat_message_bubble.dart';

class _StreamChatRepo implements ChatRepository {
  _StreamChatRepo(this.build);

  final Stream<String> Function() build;
  int streamCalls = 0;

  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) async => throw UnimplementedError();

  @override
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  }) {
    streamCalls++;
    return build();
  }
}

Widget _wrap(_StreamChatRepo repo) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ChatPage(sessionId: 's_test'),
      ),
      GoRoute(path: '/professor/:id', builder: (_, _) => const Placeholder()),
    ],
  );
  return ProviderScope(
    overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('挂载后显示标题与快捷问题', (tester) async {
    await tester.pumpWidget(
      _wrap(_StreamChatRepo(() => Stream.fromIterable(const ['x']))),
    );
    await tester.pumpAndSettle();

    expect(find.text('继续追问'), findsWidgets);
    expect(find.text('有没有相似的导师？'), findsOneWidget);
  });

  testWidgets('点击快捷问题：用户消息上屏并流式返回回答', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['流式', '回答']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('有没有相似的导师？'));
    await tester.pumpAndSettle();

    expect(find.text('有没有相似的导师？'), findsWidgets);
    expect(repo.streamCalls, 1);
    expect(find.byType(GptMarkdown), findsWidgets);
  });

  testWidgets('响应中显示「停止生成」，点击后恢复「发送」', (tester) async {
    final controller = StreamController<String>();
    addTearDown(controller.close);
    await tester.pumpWidget(_wrap(_StreamChatRepo(() => controller.stream)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士申请吗？'));
    await tester.pump();
    controller.add('部分答案');
    await tester.pump();

    expect(find.byTooltip('停止生成'), findsOneWidget);
    expect(find.byTooltip('发送'), findsNothing);

    await tester.tap(find.byTooltip('停止生成'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('发送'), findsOneWidget);
    expect(find.byTooltip('停止生成'), findsNothing);
  });

  testWidgets('重新生成会再次调用仓储', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士申请吗？'));
    await tester.pumpAndSettle();
    expect(repo.streamCalls, 1);

    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('重新生成')));
    await tester.pumpAndSettle();
    expect(repo.streamCalls, 2);
  });

  testWidgets('助手消息气泡显示操作栏工具提示', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('为什么推荐这位导师？'));
    await tester.pumpAndSettle();

    final bubble = find.byType(ChatMessageBubble).last;
    expect(find.descendant(of: bubble, matching: find.byTooltip('复制')), findsOneWidget);
    expect(find.descendant(of: bubble, matching: find.byTooltip('重新生成')), findsOneWidget);
    expect(find.descendant(of: bubble, matching: find.byTooltip('有用')), findsOneWidget);
    expect(find.descendant(of: bubble, matching: find.byTooltip('没用')), findsOneWidget);
  });

  testWidgets('点击复制按钮显示已复制提示', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士申请吗？'));
    await tester.pumpAndSettle();

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') return null;
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final bubble = find.byType(ChatMessageBubble).last;
    await tester.tap(find.descendant(of: bubble, matching: find.byTooltip('复制')));
    await tester.pumpAndSettle();

    expect(find.text('已复制'), findsOneWidget);
  });

  testWidgets('点赞按钮可切换状态', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士申请吗？'));
    await tester.pumpAndSettle();

    final bubble = find.byType(ChatMessageBubble).last;

    await tester.tap(find.descendant(of: bubble, matching: find.byTooltip('有用')));
    await tester.pumpAndSettle();

    expect(find.descendant(of: bubble, matching: find.byIcon(Icons.thumb_up)), findsOneWidget);

    await tester.tap(find.descendant(of: bubble, matching: find.byTooltip('有用')));
    await tester.pumpAndSettle();

    expect(find.descendant(of: bubble, matching: find.byIcon(Icons.thumb_up_outlined)), findsOneWidget);
  });

  testWidgets('点击单条消息重新生成会再次调用仓储', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士申请吗？'));
    await tester.pumpAndSettle();
    expect(repo.streamCalls, 1);

    final bubble = find.byType(ChatMessageBubble).last;
    await tester.tap(find.descendant(of: bubble, matching: find.byTooltip('重新生成')));
    await tester.pumpAndSettle();

    expect(repo.streamCalls, 2);
  });
}
