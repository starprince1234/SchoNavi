import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';
import 'package:scho_navi/domain/repositories/chat_repository.dart';
import 'package:scho_navi/features/chat/providers/chat_provider.dart';

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

ProviderContainer _container(_StreamChatRepo repo) {
  return ProviderContainer(
    overrides: [chatRepositoryProvider.overrideWithValue(repo)],
  );
}

void main() {
  test('设置 feedback 成功，状态更新', () async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    final container = _container(repo);
    addTearDown(container.dispose);

    final notifier = container.read(chatProvider.notifier);
    notifier.start(sessionId: 's1');

    await notifier.send('问题 1');
    await container.pump();

    final assistantMessage = container.read(chatProvider).messages.last;
    expect(assistantMessage.role, ChatRole.assistant);
    expect(assistantMessage.status, ChatMessageStatus.done);

    notifier.setFeedback(assistantMessage.id, ChatMessageFeedback.like);

    final updated = container.read(chatProvider).messages.last;
    expect(updated.id, assistantMessage.id);
    expect(updated.feedback, ChatMessageFeedback.like);
  });

  test('对用户消息设置 feedback 无效', () async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    final container = _container(repo);
    addTearDown(container.dispose);

    final notifier = container.read(chatProvider.notifier);
    notifier.start(sessionId: 's1');

    await notifier.send('问题 1');
    await container.pump();

    final userMessage = container.read(chatProvider).messages.firstWhere(
      (m) => m.role == ChatRole.user,
    );

    notifier.setFeedback(userMessage.id, ChatMessageFeedback.like);

    final unchanged = container.read(chatProvider).messages.firstWhere(
      (m) => m.id == userMessage.id,
    );
    expect(unchanged.feedback, ChatMessageFeedback.none);
  });

  test('对 streaming 中的助手消息设置 feedback 无效', () async {
    final controller = StreamController<String>();
    final repo = _StreamChatRepo(() => controller.stream);
    final container = _container(repo);
    addTearDown(() async {
      await controller.close();
      container.dispose();
    });

    final notifier = container.read(chatProvider.notifier);
    notifier.start(sessionId: 's1');

    final future = notifier.send('问题 1');
    await container.pump();

    controller.add('部分答案');
    await container.pump();

    final assistantMessage = container.read(chatProvider).messages.last;
    expect(assistantMessage.status, ChatMessageStatus.streaming);

    notifier.setFeedback(assistantMessage.id, ChatMessageFeedback.like);

    final unchanged = container.read(chatProvider).messages.last;
    expect(unchanged.feedback, ChatMessageFeedback.none);

    controller.close();
    await future;
  });

  test('重新生成单条助手消息会截断其后消息并再次调用仓储', () async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    final container = _container(repo);
    addTearDown(container.dispose);

    final notifier = container.read(chatProvider.notifier);
    notifier.start(sessionId: 's1');

    await notifier.send('问题 1');
    await container.pump();
    expect(repo.streamCalls, 1);

    final firstAssistantId = container.read(chatProvider).messages.last.id;

    await notifier.send('问题 2');
    await container.pump();
    expect(repo.streamCalls, 2);

    final messagesBeforeRegenerate = container.read(chatProvider).messages;
    expect(messagesBeforeRegenerate.length, 4);

    await notifier.regenerateMessage(firstAssistantId);
    await container.pump();

    expect(repo.streamCalls, 3);
    final messagesAfterRegenerate = container.read(chatProvider).messages;
    expect(messagesAfterRegenerate.length, 2);
    expect(
      messagesAfterRegenerate.map((m) => m.role).toList(),
      [ChatRole.user, ChatRole.assistant],
    );
  });

  test('没有用户消息时重新生成不调用仓储', () async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    final container = _container(repo);
    addTearDown(container.dispose);

    final notifier = container.read(chatProvider.notifier);
    notifier.start(sessionId: 's1');

    expect(container.read(chatProvider).messages, isEmpty);

    await notifier.regenerate();
    await container.pump();

    expect(repo.streamCalls, 0);
    expect(container.read(chatProvider).messages.length, 0);
  });
}
