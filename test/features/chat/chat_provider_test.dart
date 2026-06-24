import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
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
  void seedRecommendationTurn({
    required String sessionId,
    required String userPrompt,
    required RecommendationResult result,
  }) {}

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
  final container = ProviderContainer(
    overrides: [chatRepositoryProvider.overrideWithValue(repo)],
  );
  container.listen(_chatTestProvider, (_, _) {});
  return container;
}

final _chatTestProvider = chatProvider(Object());

void main() {
  test('start 注入会话且不带助手问候', () {
    final container = _containerWith(
      _StreamChatRepo(() => Stream.fromIterable(const ['x'])),
    );
    addTearDown(container.dispose);

    container
        .read(_chatTestProvider.notifier)
        .start(sessionId: 's_1', professorId: 'p_001');
    final state = container.read(_chatTestProvider);

    expect(state.sessionId, 's_1');
    expect(state.professorId, 'p_001');
    expect(state.messages, isEmpty);
    expect(state.isResponding, isFalse);
  });

  test('send：逐段增量累加为助手回答并置 done', () async {
    final repo = _StreamChatRepo(
      () => Stream.fromIterable(const ['测', '试', '回答']),
    );
    final container = _containerWith(repo);
    addTearDown(container.dispose);
    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 's_1', professorId: 'p_001');

    await notifier.send('为什么推荐他');
    final msgs = container.read(_chatTestProvider).messages;

    expect(msgs, hasLength(2));
    expect(msgs[0].role, ChatRole.user);
    expect(msgs[0].content, '为什么推荐他');
    expect(msgs.last.role, ChatRole.assistant);
    expect(msgs.last.status, ChatMessageStatus.done);
    expect(msgs.last.content, '测试回答');
    expect(container.read(_chatTestProvider).isResponding, isFalse);
    expect(repo.lastSessionId, 's_1');
    expect(repo.lastMessage, '为什么推荐他');
    expect(repo.lastProfessorId, 'p_001');
  });

  test('send 失败：助手消息标记 error 并显示文案', () async {
    final container = _containerWith(
      _StreamChatRepo(() => Stream<String>.error(const ServerException())),
    );
    addTearDown(container.dispose);
    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 's_1');

    await notifier.send('为什么推荐他');
    final last = container.read(_chatTestProvider).messages.last;

    expect(last.status, ChatMessageStatus.error);
    expect(last.content, '服务异常，请稍后重试');
    expect(container.read(_chatTestProvider).isResponding, isFalse);
  });

  test('流式中断时保留已生成文本并附加错误原因', () async {
    final controller = StreamController<String>();
    addTearDown(controller.close);
    final container = _containerWith(_StreamChatRepo(() => controller.stream));
    addTearDown(container.dispose);
    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 's_1');

    final pending = notifier.send('为什么推荐他');
    await Future<void>.delayed(Duration.zero);
    controller.add('已经生成的部分');
    await Future<void>.delayed(Duration.zero);
    controller.addError(const ServerException());
    await pending;

    final last = container.read(_chatTestProvider).messages.last;
    expect(last.status, ChatMessageStatus.error);
    expect(last.content, contains('已经生成的部分'));
    expect(last.content, contains('生成中断：服务异常，请稍后重试'));
  });

  test('stop：取消订阅并保留已到达文本', () async {
    final controller = StreamController<String>();
    addTearDown(controller.close);
    final container = _containerWith(_StreamChatRepo(() => controller.stream));
    addTearDown(container.dispose);
    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 's_1');

    final pending = notifier.send('为什么推荐他');
    await Future<void>.delayed(Duration.zero);
    controller.add('部分');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(_chatTestProvider).isResponding, isTrue);
    expect(
      container.read(_chatTestProvider).messages.last.status,
      ChatMessageStatus.streaming,
    );
    expect(container.read(_chatTestProvider).messages.last.content, '部分');

    await notifier.stop();
    await pending;

    final state = container.read(_chatTestProvider);
    expect(state.isResponding, isFalse);
    expect(state.messages.last.status, ChatMessageStatus.done);
    expect(state.messages.last.content, '部分');
  });

  test('regenerate 重发上一条用户消息', () async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    final container = _containerWith(repo);
    addTearDown(container.dispose);
    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 's_1');

    await notifier.send('为什么推荐他');
    expect(repo.streamCalls, 1);

    await notifier.regenerate();
    expect(repo.streamCalls, 2);
    expect(repo.lastMessage, '为什么推荐他');
    expect(container.read(_chatTestProvider).messages, hasLength(2));
    expect(container.read(_chatTestProvider).messages.last.content, '答案');
  });

  test('切换会话后旧流增量不能写入新会话', () async {
    final controller = StreamController<String>();
    addTearDown(controller.close);
    final repo = _StreamChatRepo(() => controller.stream);
    final container = _containerWith(repo);
    addTearDown(container.dispose);
    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 'old');

    final pending = notifier.send('旧问题');
    await Future<void>.delayed(Duration.zero);
    controller.add('旧增量');
    await Future<void>.delayed(Duration.zero);

    notifier.start(sessionId: 'new');
    controller.add('迟到内容');
    await controller.close();
    await pending;

    final state = container.read(_chatTestProvider);
    expect(state.sessionId, 'new');
    expect(state.messages, isEmpty);
  });
}
