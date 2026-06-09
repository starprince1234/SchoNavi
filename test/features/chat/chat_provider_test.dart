import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';
import 'package:scho_navi/domain/repositories/chat_repository.dart';
import 'package:scho_navi/features/chat/providers/chat_provider.dart';

class _FakeChatRepo implements ChatRepository {
  _FakeChatRepo(this._result);

  final Result<ChatResult> _result;
  int calls = 0;
  String? lastSessionId;
  String? lastMessage;
  String? lastProfessorId;

  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) async {
    calls++;
    lastSessionId = sessionId;
    lastMessage = message;
    lastProfessorId = professorId;
    return _result;
  }
}

ProviderContainer _containerWith(ChatRepository repo) {
  return ProviderContainer(
    overrides: [chatRepositoryProvider.overrideWithValue(repo)],
  );
}

const _okResult = ChatResult(
  sessionId: 's_1',
  answer: '测试回答',
  relatedRecommendations: [],
);

void main() {
  test('start 注入会话并植入一条助手问候', () {
    final container = _containerWith(_FakeChatRepo(const Success(_okResult)));
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

  test('send 追加用户消息与助手回答（done）', () async {
    final repo = _FakeChatRepo(const Success(_okResult));
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
    expect(repo.lastProfessorId, 'p_001');
  });

  test('send 失败：助手消息标记 error 并显示文案', () async {
    final container = _containerWith(
      _FakeChatRepo(const Failure(ServerException())),
    );
    addTearDown(container.dispose);
    final notifier = container.read(chatProvider.notifier)
      ..start(sessionId: 's_1');

    await notifier.send('为什么推荐他');
    final last = container.read(chatProvider).messages.last;

    expect(last.status, ChatMessageStatus.error);
    expect(last.content, '服务异常，请稍后重试');
  });

  test('regenerate 重发上一条用户消息', () async {
    final repo = _FakeChatRepo(const Success(_okResult));
    final container = _containerWith(repo);
    addTearDown(container.dispose);
    final notifier = container.read(chatProvider.notifier)
      ..start(sessionId: 's_1');

    await notifier.send('为什么推荐他');
    expect(repo.calls, 1);

    await notifier.regenerate();
    expect(repo.calls, 2);
    expect(repo.lastMessage, '为什么推荐他');
    expect(container.read(chatProvider).messages, hasLength(3));
  });
}
