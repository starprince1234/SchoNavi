import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/core/storage/local_store.dart';
import 'package:scho_navi/data/ai/ai_chat_repository.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';
import 'package:scho_navi/domain/entities/fork_ref.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/repositories/chat_repository.dart';
import 'package:scho_navi/features/chat/providers/chat_provider.dart';
import 'package:scho_navi/shared/utils/recommendation_need_classifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemStore implements LocalStore {
  final Map<String, dynamic> _m = {};

  @override
  String? getString(String key) => _m[key] as String?;

  @override
  Future<void> setString(String key, String value) async => _m[key] = value;

  @override
  bool? getBool(String key) => _m[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => _m[key] = value;

  @override
  Map<String, dynamic>? getJson(String key) => _m[key] as Map<String, dynamic>?;

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async =>
      _m[key] = value;

  @override
  List<dynamic>? getJsonList(String key) => _m[key] as List<dynamic>?;

  @override
  Future<void> setJsonList(String key, List<dynamic> value) async =>
      _m[key] = value;

  @override
  bool containsKey(String key) => _m.containsKey(key);

  @override
  Future<void> remove(String key) async => _m.remove(key);

  @override
  Future<void> clear() async => _m.clear();
}

class _StubLlm implements LlmClient {
  _StubLlm(this.reply);

  final String reply;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async => Success(reply);

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) async* {
    yield reply;
  }
}

class _AlwaysNeedClassifier implements RecommendationNeedClassifier {
  @override
  Future<bool> needRecommendations(
    String followUp, {
    RecommendationResult? lastResult,
  }) async => true;
}

AiChatRepository _repo() {
  SharedPreferences.setMockInitialValues({});
  return AiChatRepository(
    llm: _StubLlm('回答'),
    db: MockDb(),
    historyStore: LocalChatHistoryStore(_MemStore()),
  );
}

final _chatProvider = chatProvider(Object());

String _firstProfId() => MockDb().allProfessors.first.id;

/// 预置主 session 的可见历史（带卡片），供 fork/resume 经 loadHistory 回填。
/// 取代旧 seedRecommendationTurn 落盘路径（推荐摘要现已不进可见历史）。
Future<void> _seedVisibleHistory(
  AiChatRepository repo,
  String sessionId,
) async {
  await repo.persistMessages(sessionId, [
    ChatMessage(
      id: 'u1',
      role: ChatRole.user,
      content: '想做CV',
      createdAt: DateTime(2026, 6, 27),
      relatedRecommendations: const [],
      status: ChatMessageStatus.done,
      kind: ChatMessageKind.conversation,
    ),
    ChatMessage(
      id: 'a1',
      role: ChatRole.assistant,
      content: '为你挑了合适的导师',
      createdAt: DateTime(2026, 6, 27),
      relatedRecommendations: const [],
      status: ChatMessageStatus.done,
      kind: ChatMessageKind.recommendation,
    ),
  ]);
}

void main() {
  test('startFork 回填历史 + 设 forkAnchor', () async {
    final repo = _repo();
    // 预置主 session 历史（AiChatRepository.seedRecommendationTurn 持久化到 store）
    await _seedVisibleHistory(repo, 's1');
    final container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.listen(_chatProvider, (_, _) {});

    final notifier = container.read(_chatProvider.notifier);
    await notifier.startFork(
      sourceSessionId: 's1',
      professorId: _firstProfId(),
    );
    await Future<void>.delayed(Duration.zero);
    final state = container.read(_chatProvider);

    expect(state.forkAnchor, isNotNull);
    expect(state.sessionId, startsWith('f_s1_'));
    expect(state.messages, isNotEmpty);
  });

  test('fork 内 send 触发再推荐意图 → forkReroute 消息', () async {
    final repo = _repo();
    await _seedVisibleHistory(repo, 's1');
    final container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        recommendationNeedClassifierProvider.overrideWithValue(
          _AlwaysNeedClassifier(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(_chatProvider, (_, _) {});

    final notifier = container.read(_chatProvider.notifier);
    await notifier.startFork(
      sourceSessionId: 's1',
      professorId: _firstProfId(),
    );
    await Future<void>.delayed(Duration.zero);
    await notifier.send('换一批导师');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final state = container.read(_chatProvider);

    final reroute = state.messages
        .where((m) => m.kind == ChatMessageKind.forkReroute)
        .toList();
    expect(reroute, isNotEmpty);
    expect(reroute.single.relatedRecommendations, isEmpty);
    expect(reroute.single.status, ChatMessageStatus.done);
  });

  test('resume(fork) 通过 mainSessionId 重建 forkAnchor', () async {
    final repo = _repo();
    await _seedVisibleHistory(repo, 's1');
    final profId = _firstProfId();
    final forkRes = await repo.forkSession(
      sourceSessionId: 's1',
      professorId: profId,
    );
    final forkId = (forkRes as Success<String>).data;
    final container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.listen(_chatProvider, (_, _) {});

    final notifier = container.read(_chatProvider.notifier);
    await notifier.resume(sessionId: forkId, isFork: true, mainSessionId: 's1');
    await Future<void>.delayed(Duration.zero);
    final state = container.read(_chatProvider);

    expect(state.forkAnchor, isNotNull);
    expect(state.forkAnchor!.forkId, forkId);
    expect(state.sessionId, forkId);
    expect(state.messages, isNotEmpty);
  });

  test('resume(fork) mainSessionId 缺省 → anchor 降级为 null 不崩溃', () async {
    final repo = _repo();
    await _seedVisibleHistory(repo, 's1');
    final forkRes = await repo.forkSession(
      sourceSessionId: 's1',
      professorId: _firstProfId(),
    );
    final forkId = (forkRes as Success<String>).data;
    final container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.listen(_chatProvider, (_, _) {});

    final notifier = container.read(_chatProvider.notifier);
    await notifier.resume(sessionId: forkId, isFork: true);
    await Future<void>.delayed(Duration.zero);
    final state = container.read(_chatProvider);

    expect(state.forkAnchor, isNull); // 降级，非崩溃
    expect(state.sessionId, forkId);
    expect(state.messages, isNotEmpty);
  });

  test('copyWith 显式置 forkAnchor=null 可清空', () {
    final anchor = ForkRef(
      forkId: 'f1',
      mainSessionId: 's1',
      professorId: 'p1',
      professorName: '张三',
      university: '清华',
      college: '计算机系',
      createdAt: DateTime(2026, 6, 27),
    );
    final s = ChatState(
      sessionId: 's1',
      professorId: 'p1',
      messages: const [],
      activity: ChatActivity.idle,
      followUpQuestions: const [],
      forkAnchor: anchor,
    );
    expect(s.forkAnchor, isNotNull);
    final cleared = s.copyWith(forkAnchor: null);
    expect(cleared.forkAnchor, isNull);
    // 不传 forkAnchor 时保留原值
    final kept = s.copyWith();
    expect(kept.forkAnchor, anchor);
  });

  test('startFork race guard discards stale state write', () async {
    final repo = _ControllableChatRepository();
    final container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.listen(_chatProvider, (_, _) {});

    final notifier = container.read(_chatProvider.notifier);
    final forkFuture = notifier.startFork(
      sourceSessionId: 's1',
      professorId: 'p1',
    );

    await repo.listForksReached;

    // A newer operation bumps _operation while the first startFork is paused
    // at the listForks await.
    notifier.start(sessionId: 'new-session', professorId: 'p2');

    repo.completeListForks(
      Success([
        ForkRef(
          forkId: 'f_s1_p1',
          mainSessionId: 's1',
          professorId: 'p1',
          professorName: 'Test Prof',
          university: 'Test Univ',
          college: 'Test College',
          createdAt: DateTime(2026, 6, 27),
        ),
      ]),
    );
    await forkFuture;
    await Future<void>.delayed(Duration.zero);

    final state = container.read(_chatProvider);
    expect(state.sessionId, 'new-session');
    expect(state.professorId, 'p2');
  });

  test('startFork failure clears stale professorId and forkAnchor', () async {
    final repo = _AlwaysFailingForkRepository();
    final container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.listen(_chatProvider, (_, _) {});

    final notifier = container.read(_chatProvider.notifier);
    await notifier.startFork(sourceSessionId: 's1', professorId: 'p1');
    await Future<void>.delayed(Duration.zero);

    final state = container.read(_chatProvider);
    expect(state.sessionId, isNull);
    expect(state.professorId, isNull);
    expect(state.forkAnchor, isNull);
    expect(state.activity, ChatActivity.idle);
  });
}

class _ControllableChatRepository extends ChatRepository {
  final Completer<Result<String>> _forkSessionCompleter =
      Completer<Result<String>>();
  final Completer<Result<List<ChatMessage>>> _loadHistoryCompleter =
      Completer<Result<List<ChatMessage>>>();
  final Completer<void> _listForksReached = Completer<void>();
  Completer<Result<List<ForkRef>>>? _listForksCompleter;

  _ControllableChatRepository() {
    _forkSessionCompleter.complete(const Success('f_s1_p1'));
    _loadHistoryCompleter.complete(const Success(<ChatMessage>[]));
  }

  Future<void> get listForksReached => _listForksReached.future;

  void completeListForks(Result<List<ForkRef>> result) {
    (_listForksCompleter ??= Completer<Result<List<ForkRef>>>()).complete(
      result,
    );
  }

  @override
  Future<Result<String>> forkSession({
    required String sourceSessionId,
    required String professorId,
  }) => _forkSessionCompleter.future;

  @override
  Future<Result<List<ChatMessage>>> loadHistory({required String sessionId}) =>
      _loadHistoryCompleter.future;

  @override
  Future<Result<List<ForkRef>>> listForks({
    required String mainSessionId,
  }) async {
    _listForksReached.complete();
    final c = _listForksCompleter ??= Completer<Result<List<ForkRef>>>();
    return c.future;
  }

  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) async => Success(
    ChatResult(
      sessionId: sessionId,
      answer: '',
      relatedRecommendations: const [],
    ),
  );

  @override
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  }) => const Stream<String>.empty();

  @override
  Future<Result<void>> deleteFork({required String forkId}) async =>
      const Success(null);
}

class _AlwaysFailingForkRepository extends ChatRepository {
  @override
  Future<Result<String>> forkSession({
    required String sourceSessionId,
    required String professorId,
  }) async => const Failure<String>(UnknownException());

  @override
  Future<Result<List<ChatMessage>>> loadHistory({
    required String sessionId,
  }) async => const Success(<ChatMessage>[]);

  @override
  Future<Result<List<ForkRef>>> listForks({
    required String mainSessionId,
  }) async => const Failure<List<ForkRef>>(UnknownException());

  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) async => Success(
    ChatResult(
      sessionId: sessionId,
      answer: '',
      relatedRecommendations: const [],
    ),
  );

  @override
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  }) => const Stream<String>.empty();

  @override
  Future<Result<void>> deleteFork({required String forkId}) async =>
      const Success(null);
}
