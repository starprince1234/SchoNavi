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
import 'package:scho_navi/features/chat/widgets/chat_quick_actions.dart';
import 'package:scho_navi/shared/utils/quick_actions_source.dart';

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
    return build();
  }
}

class _ScriptedQuickActionsSource implements QuickActionsSource {
  _ScriptedQuickActionsSource();

  final List<Completer<Result<List<String>>>> _pending = [];
  Result<List<String>>? _immediate;

  /// 设置下一次 fetch 立即返回的结果（同步完成）。
  void setNext(Result<List<String>> result) => _immediate = result;

  /// 设置下一次 fetch 挂起，返回 Completer 让测试控制何时完成（竞态测试用）。
  Completer<Result<List<String>>> parkNext() {
    final c = Completer<Result<List<String>>>();
    _pending.add(c);
    return c;
  }

  @override
  Future<Result<List<String>>> fetch({
    required String followUp,
    RecommendationResult? lastResult,
  }) async {
    if (_pending.isNotEmpty) return _pending.removeAt(0).future;
    return _immediate ?? const Success(<String>[]);
  }
}

ProviderContainer _container(
  _StreamChatRepo repo, {
  _ScriptedQuickActionsSource? quickActions,
}) {
  final container = ProviderContainer(
    overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      if (quickActions != null)
        quickActionsSourceProvider.overrideWithValue(quickActions),
    ],
  );
  container.listen(_chatTestProvider, (_, _) {});
  return container;
}

final _chatTestProvider = chatProvider(Object());

void main() {
  test('设置 feedback 成功，状态更新', () async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    final container = _container(repo);
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier);
    notifier.start(sessionId: 's1');

    await notifier.send('问题 1');
    await container.pump();

    final assistantMessage = container.read(_chatTestProvider).messages.last;
    expect(assistantMessage.role, ChatRole.assistant);
    expect(assistantMessage.status, ChatMessageStatus.done);

    notifier.setFeedback(assistantMessage.id, ChatMessageFeedback.like);

    final updated = container.read(_chatTestProvider).messages.last;
    expect(updated.id, assistantMessage.id);
    expect(updated.feedback, ChatMessageFeedback.like);
  });

  test('对用户消息设置 feedback 无效', () async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    final container = _container(repo);
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier);
    notifier.start(sessionId: 's1');

    await notifier.send('问题 1');
    await container.pump();

    final userMessage = container
        .read(_chatTestProvider)
        .messages
        .firstWhere((m) => m.role == ChatRole.user);

    notifier.setFeedback(userMessage.id, ChatMessageFeedback.like);

    final unchanged = container
        .read(_chatTestProvider)
        .messages
        .firstWhere((m) => m.id == userMessage.id);
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

    final notifier = container.read(_chatTestProvider.notifier);
    notifier.start(sessionId: 's1');

    final future = notifier.send('问题 1');
    await container.pump();

    controller.add('部分答案');
    await container.pump();

    final assistantMessage = container.read(_chatTestProvider).messages.last;
    expect(assistantMessage.status, ChatMessageStatus.streaming);

    notifier.setFeedback(assistantMessage.id, ChatMessageFeedback.like);

    final unchanged = container.read(_chatTestProvider).messages.last;
    expect(unchanged.feedback, ChatMessageFeedback.none);

    controller.close();
    await future;
  });

  test('只能重新生成最新助手消息，旧消息请求被忽略', () async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    final container = _container(repo);
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier);
    notifier.start(sessionId: 's1');

    await notifier.send('问题 1');
    await container.pump();
    expect(repo.streamCalls, 1);

    final firstAssistantId = container.read(_chatTestProvider).messages.last.id;

    await notifier.send('问题 2');
    await container.pump();
    expect(repo.streamCalls, 2);

    final messagesBeforeRegenerate = container.read(_chatTestProvider).messages;
    expect(messagesBeforeRegenerate.length, 4);

    await notifier.regenerateMessage(firstAssistantId);
    await container.pump();

    expect(repo.streamCalls, 2);
    final messagesAfterRegenerate = container.read(_chatTestProvider).messages;
    expect(messagesAfterRegenerate.length, 4);
    expect(messagesAfterRegenerate.map((m) => m.role).toList(), [
      ChatRole.user,
      ChatRole.assistant,
      ChatRole.user,
      ChatRole.assistant,
    ]);
  });

  test('没有用户消息时重新生成不调用仓储', () async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    final container = _container(repo);
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier);
    notifier.start(sessionId: 's1');

    expect(container.read(_chatTestProvider).messages, isEmpty);

    await notifier.regenerate();
    await container.pump();

    expect(repo.streamCalls, 0);
    expect(container.read(_chatTestProvider).messages.length, 0);
  });

  group('quick actions 后端化', () {
    test('start 后 followUpQuestions 来自后端 Success', () async {
      final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
      final src = _ScriptedQuickActionsSource()
        ..setNext(const Success(['换一批', '偏应用']));
      final container = _container(repo, quickActions: src);
      addTearDown(container.dispose);

      container.read(_chatTestProvider.notifier).start(sessionId: 's1');
      await container.pump();

      expect(
        container.read(_chatTestProvider).followUpQuestions,
        ['换一批', '偏应用'],
      );
    });

    test('后端 Failure → fallback 到 defaultChatQuickActions', () async {
      final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
      final src = _ScriptedQuickActionsSource()
        ..setNext(const Failure(NetworkException()));
      final container = _container(repo, quickActions: src);
      addTearDown(container.dispose);

      container.read(_chatTestProvider.notifier).start(sessionId: 's1');
      await container.pump();

      expect(
        container.read(_chatTestProvider).followUpQuestions,
        defaultChatQuickActions,
      );
    });

    test('后端 Success 空列表 → followUpQuestions 为空（不显示）', () async {
      final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
      final src = _ScriptedQuickActionsSource()
        ..setNext(const Success(<String>[]));
      final container = _container(repo, quickActions: src);
      addTearDown(container.dispose);

      container.read(_chatTestProvider.notifier).start(sessionId: 's1');
      await container.pump();

      expect(
        container.read(_chatTestProvider).followUpQuestions,
        isEmpty,
      );
    });

    test('对话轮 stream onDone 后刷新 chip', () async {
      final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
      final src = _ScriptedQuickActionsSource()
        ..setNext(const Success(<String>[])); // 初始 fetch 消费
      // 初始 fetch 用 setNext 返回空；对话轮 onDone 前再 setNext 返回新 chip
      final container = _container(repo, quickActions: src);
      addTearDown(container.dispose);

      container.read(_chatTestProvider.notifier).start(sessionId: 's1');
      await container.pump(); // 初始 fetch 完成（Success 空）

      src.setNext(const Success(['再推荐', '换一批'])); // 对话轮要返回的
      await container.read(_chatTestProvider.notifier).send('继续');
      await container.pump();

      expect(
        container.read(_chatTestProvider).followUpQuestions,
        ['再推荐', '换一批'],
      );
    });

    test('过期 fetch 不覆盖新 state（token 竞态）', () async {
      final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
      final src = _ScriptedQuickActionsSource();
      final container = _container(repo, quickActions: src);
      addTearDown(container.dispose);

      // 初始 fetch 挂起
      final initialGate = src.parkNext();
      container.read(_chatTestProvider.notifier).start(sessionId: 's1');
      await container.pump();

      // 对话轮的 fetch 立即返回新值
      src.setNext(const Success(['新值']));
      await container.read(_chatTestProvider.notifier).send('继续');
      await container.pump();
      expect(
        container.read(_chatTestProvider).followUpQuestions,
        ['新值'],
      );

      // 初始 fetch 慢回来，旧值不应覆盖
      initialGate.complete(const Success(['旧值']));
      await container.pump();
      expect(
        container.read(_chatTestProvider).followUpQuestions,
        ['新值'],
        reason: '过期 fetch 的旧值不应覆盖新 state',
      );
    });
  });
}
