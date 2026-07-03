import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/conversation_aggregate.dart';
import 'package:scho_navi/domain/entities/conversation_turn.dart';
import 'package:scho_navi/features/chat/providers/chat_provider.dart';

import '../../helpers/fake_conversation_repository.dart';

final _chatTestProvider = chatProvider(Object());

ProviderContainer _containerWith(ControllableConversationRepository repo) {
  final container = ProviderContainer(
    overrides: [conversationRepositoryProvider.overrideWithValue(repo)],
  );
  container.listen(_chatTestProvider, (_, _) {});
  return container;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

ConversationAggregate _completedAggregate({
  String sessionId = 'session-1',
  String userText = '为什么推荐他',
  String answer = '测试回答',
  String turnId = 'turn-1',
  String attemptId = 'attempt-1',
  int revision = 1,
}) {
  final session = fakeSession(id: sessionId, revision: revision);
  final user = fakeUserMessage(id: 'user-$turnId', content: userText);
  final assistant = fakeAssistantMessage(
    id: 'assistant-$attemptId',
    content: answer,
  );
  return fakeAggregate(
    session: session,
    turns: [
      fakeTurn(
        id: turnId,
        sessionId: sessionId,
        status: ConversationTurnStatus.completed,
        route: ConversationRoute.conversation,
        userMessage: user,
        activeAttemptId: attemptId,
      ),
    ],
    messages: [user, assistant],
  );
}

void main() {
  test('start 注入会话且不带助手问候', () async {
    final repo = ControllableConversationRepository(
      initialAggregate: fakeAggregate(
        session: fakeSession(id: 's_1', professorId: 'p_001'),
      ),
    );
    final container = _containerWith(repo);
    addTearDown(repo.dispose);
    addTearDown(container.dispose);

    await container
        .read(_chatTestProvider.notifier)
        .start(sessionId: 's_1', professorId: 'p_001');
    final state = container.read(_chatTestProvider);

    expect(state.sessionId, 's_1');
    expect(state.professorId, 'p_001');
    expect(state.messages, isEmpty);
    expect(state.isResponding, isFalse);
  });

  test('send：事件增量进入 streaming，completed 后以聚合结果置 done', () async {
    final repo = ControllableConversationRepository();
    final container = _containerWith(repo);
    addTearDown(repo.dispose);
    addTearDown(container.dispose);
    final notifier = container.read(_chatTestProvider.notifier);
    await notifier.resume(sessionId: 'session-1');

    final pending = notifier.send('为什么推荐他');
    await _flush();
    repo
      ..emit(acknowledged())
      ..emit(routed())
      ..emit(delta(text: '测'))
      ..emit(delta(text: '试回答'));
    await _flush();

    var state = container.read(_chatTestProvider);
    expect(state.messages, hasLength(2));
    expect(state.messages.last.status, ChatMessageStatus.streaming);
    expect(state.messages.last.content, '测试回答');
    expect(state.activity, ChatActivity.streaming);

    final aggregate = _completedAggregate();
    repo.setAggregate(aggregate);
    repo.emit(completed(message: aggregate.messages.last, session: aggregate.session));
    await repo.closeActiveEvents();
    await pending;

    state = container.read(_chatTestProvider);
    expect(state.messages, hasLength(2));
    expect(state.messages.first.role, ChatRole.user);
    expect(state.messages.first.content, '为什么推荐他');
    expect(state.messages.last.role, ChatRole.assistant);
    expect(state.messages.last.status, ChatMessageStatus.done);
    expect(state.messages.last.content, '测试回答');
    expect(state.isResponding, isFalse);
    expect(repo.submitCalls.single.sessionId, 'session-1');
    expect(repo.submitCalls.single.text, '为什么推荐他');
  });

  test('send 失败：SSE error 保留 AppException 并生成错误消息', () async {
    final repo = ControllableConversationRepository();
    final container = _containerWith(repo);
    addTearDown(repo.dispose);
    addTearDown(container.dispose);
    final notifier = container.read(_chatTestProvider.notifier);
    await notifier.resume(sessionId: 'session-1');

    final pending = notifier.send('为什么推荐他');
    await _flush();
    repo
      ..emit(acknowledged())
      ..emit(routed())
      ..emit(failed(message: '服务异常，请稍后重试', code: 'SERVER_ERROR'));
    await repo.closeActiveEvents();
    await pending;

    final state = container.read(_chatTestProvider);
    expect(state.activity, ChatActivity.turnFailed);
    expect(state.error, isA<ValidationException>());
    expect(state.error?.diagnostics?.backendCode, 'SERVER_ERROR');
    expect(state.messages.last.status, ChatMessageStatus.error);
    expect(state.messages.last.content, '服务异常，请稍后重试');
  });

  test('流式中断时 hydrate 后保留已生成文本并附加错误原因', () async {
    final repo = ControllableConversationRepository();
    final container = _containerWith(repo);
    addTearDown(repo.dispose);
    addTearDown(container.dispose);
    final notifier = container.read(_chatTestProvider.notifier);
    await notifier.resume(sessionId: 'session-1');

    final pending = notifier.send('为什么推荐他');
    await _flush();
    repo
      ..emit(acknowledged())
      ..emit(routed())
      ..emit(delta(text: '已经生成的部分'));
    await _flush();

    final user = fakeUserMessage(content: '为什么推荐他');
    final partial = fakeAssistantMessage(
      id: 'assistant-attempt-1',
      content: '已经生成的部分',
      status: ChatMessageStatus.interrupted,
    );
    repo.setAggregate(
      fakeAggregate(
        session: fakeSession(revision: 1),
        turns: [
          fakeTurn(
            status: ConversationTurnStatus.interrupted,
            userMessage: user,
          ),
        ],
        messages: [user, partial],
      ),
    );
    repo.emit(failed(message: '生成中断：服务异常，请稍后重试'));
    await repo.closeActiveEvents();
    await pending;

    final state = container.read(_chatTestProvider);
    expect(state.messages.any((m) => m.content == '已经生成的部分'), isTrue);
    expect(state.messages.last.status, ChatMessageStatus.error);
    expect(state.messages.last.content, '生成中断：服务异常，请稍后重试');
  });

  test('stop：取消 attempt 并 hydrate 为中断态', () async {
    final repo = ControllableConversationRepository();
    final container = _containerWith(repo);
    addTearDown(repo.dispose);
    addTearDown(container.dispose);
    final notifier = container.read(_chatTestProvider.notifier);
    await notifier.resume(sessionId: 'session-1');

    final pending = notifier.send('为什么推荐他');
    await _flush();
    repo
      ..emit(acknowledged(attemptId: 'attempt-stop'))
      ..emit(routed(attemptId: 'attempt-stop'))
      ..emit(delta(attemptId: 'attempt-stop', text: '部分'));
    await _flush();

    expect(container.read(_chatTestProvider).isResponding, isTrue);
    expect(container.read(_chatTestProvider).messages.last.content, '部分');

    final user = fakeUserMessage(content: '为什么推荐他');
    final partial = fakeAssistantMessage(
      id: 'assistant-attempt-stop',
      content: '部分',
      status: ChatMessageStatus.interrupted,
    );
    repo.setAggregate(
      fakeAggregate(
        session: fakeSession(revision: 1),
        turns: [
          fakeTurn(
            status: ConversationTurnStatus.interrupted,
            userMessage: user,
            activeAttemptId: 'attempt-stop',
          ),
        ],
        messages: [user, partial],
      ),
    );

    await notifier.stop();
    await pending;

    final state = container.read(_chatTestProvider);
    expect(repo.cancelCalls, ['attempt-stop']);
    expect(state.isResponding, isFalse);
    expect(state.activity, ChatActivity.interrupted);
    expect(state.messages.last.status, ChatMessageStatus.interrupted);
    expect(state.messages.last.content, '部分');
  });

  test('regenerate 重发上一轮 turn', () async {
    final aggregate = _completedAggregate();
    final repo = ControllableConversationRepository(initialAggregate: aggregate);
    final container = _containerWith(repo);
    addTearDown(repo.dispose);
    addTearDown(container.dispose);
    final notifier = container.read(_chatTestProvider.notifier);
    await notifier.resume(sessionId: 'session-1');

    final pending = notifier.regenerate();
    await _flush();
    repo
      ..emit(acknowledged(turnId: 'turn-1', attemptId: 'attempt-2', revision: 1))
      ..emit(routed(turnId: 'turn-1', attemptId: 'attempt-2', revision: 1))
      ..emit(
        delta(
          turnId: 'turn-1',
          attemptId: 'attempt-2',
          revision: 1,
          text: '新答案',
        ),
      );
    await _flush();

    final nextAggregate = _completedAggregate(
      answer: '新答案',
      attemptId: 'attempt-2',
      revision: 2,
    );
    repo.setAggregate(nextAggregate);
    repo.emit(
      completed(
        turnId: 'turn-1',
        attemptId: 'attempt-2',
        revision: 2,
        message: nextAggregate.messages.last,
        session: nextAggregate.session,
      ),
    );
    await repo.closeActiveEvents();
    await pending;

    expect(repo.regenerateCalls.single.turnId, 'turn-1');
    expect(
      container.read(_chatTestProvider).messages.map((m) => m.content),
      contains('新答案'),
    );
  });

  test('切换会话后旧流增量不能写入新会话', () async {
    final repo = ControllableConversationRepository(
      initialAggregate: fakeAggregate(session: fakeSession(id: 'old')),
    );
    repo.setAggregate(fakeAggregate(session: fakeSession(id: 'new')));
    final container = _containerWith(repo);
    addTearDown(repo.dispose);
    addTearDown(container.dispose);
    final notifier = container.read(_chatTestProvider.notifier);
    await notifier.start(sessionId: 'old');

    final pending = notifier.send('旧问题');
    await _flush();
    repo
      ..emit(acknowledged(sessionId: 'old'))
      ..emit(routed(sessionId: 'old'))
      ..emit(delta(sessionId: 'old', text: '旧增量'));
    await _flush();

    await notifier.start(sessionId: 'new');
    repo.emit(delta(sessionId: 'old', text: '迟到内容'));
    await pending;

    final state = container.read(_chatTestProvider);
    expect(state.sessionId, 'new');
    expect(
      state.messages.any((message) => message.content.contains('迟到内容')),
      isFalse,
    );
  });
}
