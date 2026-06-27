import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';
import 'package:scho_navi/domain/entities/competition_recommendation_result.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/entities/search_history_item.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/entities/fork_ref.dart';
import 'package:scho_navi/domain/repositories/chat_repository.dart';
import 'package:scho_navi/domain/repositories/history_repository.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/domain/repositories/recommendation_repository.dart';
import 'package:scho_navi/features/chat/providers/chat_provider.dart';
import 'package:scho_navi/shared/utils/recommendation_need_classifier.dart';

/// 可控流式 chat 仓储：记录推荐上下文注入，普通追问返回固定流。
class _StreamChatRepo implements ChatRepository {
  _StreamChatRepo(this.stream);

  final Stream<String> Function() stream;
  int seedCalls = 0;
  String? lastSeedSessionId;
  RecommendationResult? lastSeedResult;
  int streamCalls = 0;
  String? lastSessionId;
  String? lastMessage;

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
  }) {
    seedCalls++;
    lastSeedSessionId = sessionId;
    lastSeedResult = result;
  }

  @override
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  }) {
    streamCalls++;
    lastSessionId = sessionId;
    lastMessage = message;
    return stream();
  }

  @override
  Future<Result<String>> forkSession({
    required String sourceSessionId,
    required String professorId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Result<List<ChatMessage>>> loadHistory({
    required String sessionId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Result<List<ForkRef>>> listForks({
    required String mainSessionId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> deleteFork({required String forkId}) async =>
      throw UnimplementedError();
}

class _FakeRecRepo implements RecommendationRepository {
  _FakeRecRepo(this._result);
  final Result<RecommendationResult> _result;
  int calls = 0;
  String? lastPrompt;
  String? lastSessionId;

  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) async {
    calls++;
    lastPrompt = prompt;
    lastSessionId = sessionId;
    return _result;
  }
}

class _CompleterRecRepo implements RecommendationRepository {
  final completer = Completer<Result<RecommendationResult>>();
  int calls = 0;

  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) {
    calls++;
    return completer.future;
  }
}

class _QueueRecRepo implements RecommendationRepository {
  _QueueRecRepo(this.results);

  final List<Result<RecommendationResult>> results;
  int calls = 0;

  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) async => results[calls++];
}

class _FakeNeedClassifier implements RecommendationNeedClassifier {
  _FakeNeedClassifier(this._value);
  final bool _value;
  int calls = 0;
  @override
  Future<bool> needRecommendations(
    String followUp, {
    RecommendationResult? lastResult,
  }) async {
    calls++;
    return _value;
  }
}

class _BlockingNeedClassifier implements RecommendationNeedClassifier {
  final completer = Completer<bool>();
  int calls = 0;

  @override
  Future<bool> needRecommendations(
    String followUp, {
    RecommendationResult? lastResult,
  }) {
    calls++;
    return completer.future;
  }
}

class _FakeProfileRepo implements ProfileRepository {
  @override
  UserProfile load() => const UserProfile();
  @override
  Future<void> save(UserProfile profile) async {}
  @override
  Future<void> clear() async {}
}

/// 内存假 history 仓储，避免 sharedPrefs 依赖，聚焦 chat 逻辑测试。
class _FakeHistoryRepo implements HistoryRepository {
  int addCalls = 0;
  @override
  List<SearchHistoryItem> list() => const [];
  @override
  Stream<List<SearchHistoryItem>> watch() => const Stream.empty();
  @override
  Future<void> addFromResult({
    required String prompt,
    required RecommendationResult result,
  }) async {
    addCalls++;
  }

  @override
  Future<void> addFromCompetitionResult({
    required String prompt,
    required CompetitionRecommendationResult result,
  }) async {}
  @override
  Future<void> remove(String sessionId) async {}
  @override
  Future<void> clear() async {}
}

RecommendationResult _recResult({String sessionId = 's_rec'}) =>
    RecommendationResult(
      sessionId: sessionId,
      queryUnderstanding: const QueryUnderstanding(
        researchInterests: ['计算机视觉'],
        preferredLocations: ['北京'],
        preferredUniversities: [],
        degreeStage: null,
        uncertainties: [],
      ),
      recommendations: const [
        Recommendation(
          professorId: 'p_001',
          name: '张三',
          university: '清华大学',
          college: '计算机学院',
          title: '教授',
          researchFields: ['计算机视觉'],
          matchLevel: MatchLevel.high,
          reason: '方向契合',
          limitations: [],
        ),
        Recommendation(
          professorId: 'p_002',
          name: '李四',
          university: '北京大学',
          college: '信息科学技术学院',
          title: '副教授',
          researchFields: ['计算机视觉'],
          matchLevel: MatchLevel.medium,
          reason: '方向相关',
          limitations: [],
        ),
      ],
      followUpQuestions: const ['只看北京', '偏理论'],
    );

ProviderContainer _container({
  required ChatRepository chatRepo,
  required RecommendationRepository recRepo,
  required RecommendationNeedClassifier needClassifier,
}) {
  final container = ProviderContainer(
    overrides: [
      chatRepositoryProvider.overrideWithValue(chatRepo),
      recommendationRepositoryProvider.overrideWithValue(recRepo),
      recommendationNeedClassifierProvider.overrideWithValue(needClassifier),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
      historyRepositoryProvider.overrideWithValue(_FakeHistoryRepo()),
    ],
  );
  container.listen(_chatTestProvider, (_, _) {});
  return container;
}

final _chatTestProvider = chatProvider(Object());

void main() {
  test('bootstrapRecommendations：首轮产用户消息 + 助手消息含推荐卡片', () async {
    final chat = _StreamChatRepo(() => Stream.fromIterable(const ['可以']));
    final rec = _FakeRecRepo(Success(_recResult()));
    final need = _FakeNeedClassifier(false);
    final container = _container(
      chatRepo: chat,
      recRepo: rec,
      needClassifier: need,
    );
    addTearDown(container.dispose);

    container.read(_chatTestProvider.notifier).start(sessionId: 'tmp');
    await container
        .read(_chatTestProvider.notifier)
        .bootstrapRecommendations('想做计算机视觉，想去北京');
    await container.pump();

    final state = container.read(_chatTestProvider);
    expect(state.sessionId, 's_rec'); // 用 result.sessionId
    expect(state.messages, hasLength(2));
    expect(state.messages[0].role, ChatRole.user);
    expect(state.messages[0].content, '想做计算机视觉，想去北京');
    expect(state.messages[1].role, ChatRole.assistant);
    expect(state.messages[1].status, ChatMessageStatus.done);
    expect(state.messages[1].relatedRecommendations, hasLength(2));
    expect(state.messages[1].relatedRecommendations.first.name, '张三');
    // 开场白应含「为你挑了 N 位」。
    expect(state.messages[1].content, contains('为你挑了'));
    // 推荐上下文被注入，sessionId 与推荐结果一致。
    expect(chat.seedCalls, 1);
    expect(chat.lastSeedSessionId, 's_rec');
    expect(chat.lastSeedResult?.sessionId, 's_rec');
    // 推荐轮不再额外调用聊天 LLM。
    expect(chat.streamCalls, 0);
    expect(rec.calls, 1);
    expect(rec.lastSessionId, 'tmp');
    expect(state.followUpQuestions, ['只看北京', '偏理论']);
  });

  test('bootstrapRecommendations 守卫：messages 非空时不重复产卡', () async {
    final chat = _StreamChatRepo(() => Stream.fromIterable(const ['x']));
    final rec = _FakeRecRepo(Success(_recResult()));
    final need = _FakeNeedClassifier(false);
    final container = _container(
      chatRepo: chat,
      recRepo: rec,
      needClassifier: need,
    );
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 'tmp');
    await notifier.bootstrapRecommendations('第一次');
    await container.pump();
    expect(rec.calls, 1);

    // 第二次调用：已有消息，应被守卫忽略。
    await notifier.bootstrapRecommendations('第二次');
    await container.pump();
    expect(rec.calls, 1); // 不再调推荐仓储
    expect(container.read(_chatTestProvider).messages, hasLength(2)); // 消息不增加
  });

  test('追问经 needClassifier 命中：新助手消息含推荐卡片', () async {
    final chat = _StreamChatRepo(() => Stream.fromIterable(const ['好的']));
    final rec = _FakeRecRepo(Success(_recResult()));
    final need = _FakeNeedClassifier(true); // 命中产卡
    final container = _container(
      chatRepo: chat,
      recRepo: rec,
      needClassifier: need,
    );
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 'tmp');
    await notifier.bootstrapRecommendations('想做CV');
    await container.pump();

    await notifier.send('只看上海的');
    await container.pump();

    final msgs = container.read(_chatTestProvider).messages;
    expect(msgs, hasLength(4)); // user, assistant(首轮), user(追问), assistant(追问)
    final followupAssistant = msgs.last;
    expect(followupAssistant.role, ChatRole.assistant);
    expect(followupAssistant.relatedRecommendations, hasLength(2));
    expect(need.calls, 1);
    expect(rec.calls, 2); // 首轮 + 追问各一次
  });

  test('追问未命中：纯文字流式，无推荐卡片', () async {
    final chat = _StreamChatRepo(() => Stream.fromIterable(const ['解释']));
    final rec = _FakeRecRepo(Success(_recResult()));
    final need = _FakeNeedClassifier(false); // 不产卡
    final container = _container(
      chatRepo: chat,
      recRepo: rec,
      needClassifier: need,
    );
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 'tmp');
    await notifier.bootstrapRecommendations('想做CV');
    await container.pump();

    await notifier.send('为什么推荐他');
    await container.pump();

    final followupAssistant = container.read(_chatTestProvider).messages.last;
    expect(followupAssistant.role, ChatRole.assistant);
    expect(followupAssistant.relatedRecommendations, isEmpty);
    expect(rec.calls, 1); // 仅首轮，追问未再调
  });

  test('推荐获取失败：显示可重试的推荐错误，不调用聊天流', () async {
    final chat = _StreamChatRepo(() => Stream.fromIterable(const ['兜底回复']));
    final rec = _FakeRecRepo(const Failure(ServerException()));
    final need = _FakeNeedClassifier(false);
    final container = _container(
      chatRepo: chat,
      recRepo: rec,
      needClassifier: need,
    );
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 'tmp');
    await notifier.bootstrapRecommendations('想做CV');
    await container.pump();

    final msgs = container.read(_chatTestProvider).messages;
    expect(msgs, hasLength(2));
    final assistant = msgs.last;
    expect(assistant.role, ChatRole.assistant);
    expect(assistant.status, ChatMessageStatus.error);
    expect(assistant.kind, ChatMessageKind.recommendation);
    expect(assistant.relatedRecommendations, isEmpty);
    expect(chat.streamCalls, 0);
  });

  test('regenerate 不重新调用推荐仓储（卡片沿用原结果）', () async {
    final chat = _StreamChatRepo(() => Stream.fromIterable(const ['再答']));
    final rec = _FakeRecRepo(Success(_recResult()));
    final need = _FakeNeedClassifier(false);
    final container = _container(
      chatRepo: chat,
      recRepo: rec,
      needClassifier: need,
    );
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 'tmp');
    await notifier.bootstrapRecommendations('想做CV');
    await container.pump();
    final recCallsBefore = rec.calls;

    await notifier.regenerate();
    await container.pump();

    expect(rec.calls, recCallsBefore); // regenerate 没多调推荐
  });

  test('推荐请求未完成时重复提交被忽略', () async {
    final chat = _StreamChatRepo(() => Stream.fromIterable(const ['x']));
    final rec = _CompleterRecRepo();
    final need = _FakeNeedClassifier(false);
    final container = _container(
      chatRepo: chat,
      recRepo: rec,
      needClassifier: need,
    );
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 's_unique');
    final pending = notifier.bootstrapRecommendations('第一次');
    await container.pump();

    expect(
      container.read(_chatTestProvider).activity,
      ChatActivity.recommending,
    );
    await notifier.bootstrapRecommendations('第二次');
    await notifier.send('重复追问');
    expect(rec.calls, 1);
    expect(container.read(_chatTestProvider).messages, hasLength(2)); // user + 占位

    rec.completer.complete(Success(_recResult(sessionId: 's_unique')));
    await pending;
    expect(container.read(_chatTestProvider).messages, hasLength(2));
  });

  test('分类未完成时重复发送只保留第一条用户消息', () async {
    final chat = _StreamChatRepo(() => Stream.fromIterable(const ['解释']));
    final rec = _FakeRecRepo(Success(_recResult()));
    final need = _BlockingNeedClassifier();
    final container = _container(
      chatRepo: chat,
      recRepo: rec,
      needClassifier: need,
    );
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 's1');
    final pending = notifier.send('第一条');
    await container.pump();
    await notifier.send('第二条');

    expect(need.calls, 1);
    expect(
      container.read(_chatTestProvider).activity,
      ChatActivity.classifying,
    );
    expect(container.read(_chatTestProvider).messages, hasLength(1));

    need.completer.complete(false);
    await pending;
    expect(container.read(_chatTestProvider).messages, hasLength(2));
  });

  test('切换会话后旧推荐结果不能覆盖新会话', () async {
    final chat = _StreamChatRepo(() => Stream.fromIterable(const ['x']));
    final rec = _CompleterRecRepo();
    final need = _FakeNeedClassifier(false);
    final container = _container(
      chatRepo: chat,
      recRepo: rec,
      needClassifier: need,
    );
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 'old');
    final pending = notifier.bootstrapRecommendations('旧请求');
    await container.pump();

    notifier.start(sessionId: 'new');
    rec.completer.complete(Success(_recResult(sessionId: 'old')));
    await pending;

    final state = container.read(_chatTestProvider);
    expect(state.sessionId, 'new');
    expect(state.messages, isEmpty);
    expect(chat.seedCalls, 0);
  });

  test('推荐失败后可重试并成功产卡', () async {
    final chat = _StreamChatRepo(() => Stream.fromIterable(const ['x']));
    final rec = _QueueRecRepo([
      const Failure(ServerException()),
      Success(_recResult()),
    ]);
    final need = _FakeNeedClassifier(false);
    final container = _container(
      chatRepo: chat,
      recRepo: rec,
      needClassifier: need,
    );
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 's1');
    await notifier.bootstrapRecommendations('想做CV');
    final errorMessage = container.read(_chatTestProvider).messages.last;
    expect(errorMessage.status, ChatMessageStatus.error);

    await notifier.retryRecommendation(errorMessage.id);
    final state = container.read(_chatTestProvider);
    expect(rec.calls, 2);
    expect(state.messages, hasLength(2));
    expect(state.messages.last.relatedRecommendations, isNotEmpty);
  });

  test('bootstrap 进行中：末尾为 sending 占位助手消息', () async {
    final chat = _StreamChatRepo(() => Stream.fromIterable(const ['x']));
    final rec = _CompleterRecRepo();
    final need = _FakeNeedClassifier(false);
    final container = _container(
      chatRepo: chat,
      recRepo: rec,
      needClassifier: need,
    );
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 'tmp');
    final pending = notifier.bootstrapRecommendations('想做CV');
    await container.pump();

    final msgs = container.read(_chatTestProvider).messages;
    expect(msgs, hasLength(2)); // user + 占位
    expect(msgs[0].role, ChatRole.user);
    expect(msgs[1].role, ChatRole.assistant);
    expect(msgs[1].status, ChatMessageStatus.sending);
    expect(msgs[1].kind, ChatMessageKind.recommendation);
    expect(msgs[1].content, '');
    expect(msgs[1].relatedRecommendations, isEmpty);

    rec.completer.complete(Success(_recResult()));
    await pending;
    await container.pump();
    // 完成后占位被替换为结果消息，仍是 2 条。
    final done = container.read(_chatTestProvider).messages;
    expect(done, hasLength(2));
    expect(done[1].status, ChatMessageStatus.done);
    expect(done[1].relatedRecommendations, hasLength(2));
  });

  test('send 推荐命中：占位替换为结果，不追加第三条', () async {
    final chat = _StreamChatRepo(() => Stream.fromIterable(const ['x']));
    final rec = _FakeRecRepo(Success(_recResult()));
    final need = _FakeNeedClassifier(true); // 追问命中产卡
    final container = _container(
      chatRepo: chat,
      recRepo: rec,
      needClassifier: need,
    );
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 'tmp');
    await notifier.bootstrapRecommendations('想做CV'); // 首轮 2 条
    await container.pump();

    await notifier.send('只看北京的');
    await container.pump();

    final msgs = container.read(_chatTestProvider).messages;
    expect(msgs, hasLength(4)); // user, assistant(首轮), user(追问), assistant(追问)
    expect(msgs.last.role, ChatRole.assistant);
    expect(msgs.last.status, ChatMessageStatus.done);
    expect(msgs.last.kind, ChatMessageKind.recommendation);
    expect(msgs.last.relatedRecommendations, hasLength(2));
  });

  test('send 推荐失败：占位替换为 error，不追加第三条', () async {
    final chat = _StreamChatRepo(() => Stream.fromIterable(const ['x']));
    final rec = _FakeRecRepo(const Failure(ServerException()));
    final need = _FakeNeedClassifier(true); // 命中产卡但推荐失败
    final container = _container(
      chatRepo: chat,
      recRepo: rec,
      needClassifier: need,
    );
    addTearDown(container.dispose);

    final notifier = container.read(_chatTestProvider.notifier)
      ..start(sessionId: 'tmp');
    await notifier.bootstrapRecommendations('想做CV');
    await container.pump();

    await notifier.send('只看北京的');
    await container.pump();

    final msgs = container.read(_chatTestProvider).messages;
    expect(msgs, hasLength(4));
    expect(msgs.last.status, ChatMessageStatus.error);
    expect(msgs.last.kind, ChatMessageKind.recommendation);
  });
}
