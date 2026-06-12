import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';
import 'package:scho_navi/domain/repositories/chat_repository.dart';
import 'package:scho_navi/features/chat/pages/chat_page.dart';

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

    expect(find.text('继续追问'), findsOneWidget);
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

    await tester.tap(find.byTooltip('重新生成'));
    await tester.pumpAndSettle();
    expect(repo.streamCalls, 2);
  });
}
