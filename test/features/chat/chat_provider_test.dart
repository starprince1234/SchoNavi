import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';
import 'package:scho_navi/domain/repositories/chat_repository.dart';
import 'package:scho_navi/features/chat/providers/chat_provider.dart';

class _StreamChatRepo implements ChatRepository {
  _StreamChatRepo(this.build);

  final Stream<String> Function() build;
  int streamCalls = 0;
  String? lastSessionId;
  String? lastMessage;
  String? lastProfessorId;

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
    lastSessionId = sessionId;
    lastMessage = message;
    lastProfessorId = professorId;
    return build();
  }
}

ProviderContainer _containerWith(ChatRepository repo) {
  return ProviderContainer(
    overrides: [chatRepositoryProvider.overrideWithValue(repo)],
  );
}

void main() {
  test('start 注入会话并植入一条助手问候', () {
    final container = _containerWith(
      _StreamChatRepo(() => Stream.fromIterable(const ['x'])),
    );
    addTearDown(container.dispose);

    container
        .read(chatProvider.notifier)
        .start(sessionId: 's_1', professorId: 'p_001');
    final state = container.read(chatProvider);

    expect(state.sessionId, 's_1');
    expect(state.professorId, 'p_001');
    expect(state.messages, hasLength(1));
    expect(state.messages.single.role, ChatRole.assistant);
    expect(state.isResponding, isFalse);
  });

  test('send：逐段增量累加为助手回答并置 done', () async {
    final repo = _StreamChatRepo(
      () => Stream.fromIterable(const ['测', '试', '回答']),
    );
    final container = _containerWith(repo);
    addTearDown(container.dispose);
    final notifier = container.read(chatProvider.notifier)
      ..start(sessionId: 's_1', professorId: 'p_001');

    await notifier.send('为什么推荐他');
    final msgs = container.read(chatProvider).messages;

    expect(msgs, hasLength(3));
    expect(msgs[1].role, ChatRole.user);
    expect(msgs[1].content, '为什么推荐他');
    expect(msgs.last.role, ChatRole.assistant);
    expect(msgs.last.status, ChatMessageStatus.done);
    expect(msgs.last.content, '测试回答');
    expect(container.read(chatProvider).isResponding, isFalse);
    expect(repo.lastSessionId, 's_1');
    expect(repo.lastMessage, '为什么推荐他');
    expect(repo.lastProfessorId, 'p_001');
  });

  test('send 失败：助手消息标记 error 并显示文案', () async {
    final container = _containerWith(
      _StreamChatRepo(() => Stream<String>.error(const ServerException())),
    );
    addTearDown(container.dispose);
    final notifier = container.read(chatProvider.notifier)
      ..start(sessionId: 's_1');

    await notifier.send('为什么推荐他');
    final last = container.read(chatProvider).messages.last;

    expect(last.status, ChatMessageStatus.error);
    expect(last.content, '服务异常，请稍后重试');
    expect(container.read(chatProvider).isResponding, isFalse);
  });

  test('stop：取消订阅并保留已到达文本', () async {
    final controller = StreamController<String>();
    addTearDown(controller.close);
    final container = _containerWith(_StreamChatRepo(() => controller.stream));
    addTearDown(container.dispose);
    final notifier = container.read(chatProvider.notifier)
      ..start(sessionId: 's_1');

    final pending = notifier.send('为什么推荐他');
    await Future<void>.delayed(Duration.zero);
    controller.add('部分');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(chatProvider).isResponding, isTrue);
    expect(container.read(chatProvider).messages.last.status, ChatMessageStatus.streaming);
    expect(container.read(chatProvider).messages.last.content, '部分');

    await notifier.stop();
    await pending;

    final state = container.read(chatProvider);
    expect(state.isResponding, isFalse);
    expect(state.messages.last.status, ChatMessageStatus.done);
    expect(state.messages.last.content, '部分');
  });

  test('regenerate 重发上一条用户消息', () async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    final container = _containerWith(repo);
    addTearDown(container.dispose);
    final notifier = container.read(chatProvider.notifier)
      ..start(sessionId: 's_1');

    await notifier.send('为什么推荐他');
    expect(repo.streamCalls, 1);

    await notifier.regenerate();
    expect(repo.streamCalls, 2);
    expect(repo.lastMessage, '为什么推荐他');
    expect(container.read(chatProvider).messages, hasLength(3));
    expect(container.read(chatProvider).messages.last.content, '答案');
  });
}
