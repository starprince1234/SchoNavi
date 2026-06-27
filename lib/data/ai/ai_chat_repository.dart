import 'dart:async';

import '../../core/ai/llm_client.dart';
import '../../core/result/result.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_result.dart';
import '../../domain/entities/fork_ref.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../domain/repositories/chat_repository.dart';
import '../local/chat_history_store.dart';
import '../mock/mock_db.dart';

class AiChatRepository implements ChatRepository {
  AiChatRepository({
    required this.llm,
    required this.db,
    required this.historyStore,
  });

  final LlmClient llm;
  final MockDb db;
  final ChatHistoryStore historyStore;
  final Map<String, List<LlmMessage>> _history = {};

  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) async {
    await _ensureHistoryLoaded(sessionId);
    final history = _history.putIfAbsent(sessionId, () => []);
    final isRegenerate =
        history.length >= 2 &&
        history[history.length - 2].role == 'user' &&
        history[history.length - 2].content == message &&
        history.last.role == 'assistant';

    if (isRegenerate) {
      history.removeLast();
    } else {
      history.add(LlmMessage('user', message));
    }

    final res = await llm.complete(
      messages: [LlmMessage('system', _systemPrompt(professorId)), ...history],
    );

    if (res is Failure<String>) return Failure(res.error);

    final answer = (res as Success<String>).data;
    history.add(LlmMessage('assistant', answer));
    await _persistHistory(sessionId);
    return Success(
      ChatResult(
        sessionId: sessionId,
        answer: answer,
        relatedRecommendations: const [],
      ),
    );
  }

  @override
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  }) {
    final buffer = StringBuffer();
    StreamSubscription<String>? sub;
    List<LlmMessage>? activeHistory;
    var failed = false;
    var persisted = false;

    void persistIfNeeded() {
      final history = activeHistory;
      if (history != null && !persisted && !failed && buffer.isNotEmpty) {
        history.add(LlmMessage('assistant', buffer.toString()));
        persisted = true;
      }
    }

    late final StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () async {
        await _ensureHistoryLoaded(sessionId);
        final history = _history.putIfAbsent(sessionId, () => []);
        activeHistory = history;
        final isRegenerate =
            history.length >= 2 &&
            history[history.length - 2].role == 'user' &&
            history[history.length - 2].content == message &&
            history.last.role == 'assistant';

        if (isRegenerate) {
          history.removeLast();
        } else {
          history.add(LlmMessage('user', message));
        }

        try {
          sub = llm
              .stream(
                messages: [
                  LlmMessage('system', _systemPrompt(professorId)),
                  ...history,
                ],
              )
              .listen(
                (delta) {
                  buffer.write(delta);
                  controller.add(delta);
                },
                onError: (Object error, StackTrace stackTrace) {
                  failed = true;
                  controller.addError(error, stackTrace);
                  unawaited(controller.close());
                },
                onDone: () async {
                  persistIfNeeded();
                  await _persistHistory(sessionId);
                  unawaited(controller.close());
                },
                cancelOnError: true,
              );
        } catch (error, stackTrace) {
          failed = true;
          controller.addError(error, stackTrace);
          unawaited(controller.close());
        }
      },
      onCancel: () async {
        persistIfNeeded();
        await _persistHistory(sessionId);
        await sub?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<void> seedRecommendationTurn({
    required String sessionId,
    required String userPrompt,
    required RecommendationResult result,
  }) async {
    await _ensureHistoryLoaded(sessionId);
    final history = _history.putIfAbsent(sessionId, () => []);
    history.add(LlmMessage('user', userPrompt));
    history.add(LlmMessage('assistant', _summarizeRecommendations(result)));
    await _persistHistory(sessionId);
  }

  // ---- persistence helpers ----

  LlmMessage _toLlmMessage(ChatMessage m) =>
      LlmMessage(m.role == ChatRole.user ? 'user' : 'assistant', m.content);

  Future<void> _ensureHistoryLoaded(String sessionId) async {
    if (_history.containsKey(sessionId)) return;
    final msgs = await historyStore.load(sessionId) ?? const [];
    _history[sessionId] = msgs.map(_toLlmMessage).toList();
  }

  Future<void> _persistHistory(String sessionId) async {
    final history = _history[sessionId];
    if (history == null) return;
    final now = DateTime.now();
    await historyStore.save(
      sessionId,
      history.indexed.map((entry) {
        final (index, m) = entry;
        return ChatMessage(
          id: 'm$index',
          role: m.role == 'user' ? ChatRole.user : ChatRole.assistant,
          content: m.content,
          createdAt: now,
          relatedRecommendations: const [],
          status: ChatMessageStatus.done,
          kind: ChatMessageKind.conversation,
        );
      }).toList(),
    );
  }

  // ---- fork CRUD: stubs; real implementation provided by Task 6 ChatForkMixin ----

  @override
  Future<Result<String>> forkSession({
    required String sourceSessionId,
    required String professorId,
  }) async {
    throw UnimplementedError('forkSession will be implemented by ChatForkMixin');
  }

  @override
  Future<Result<List<ChatMessage>>> loadHistory({
    required String sessionId,
  }) async {
    throw UnimplementedError('loadHistory will be implemented by ChatForkMixin');
  }

  @override
  Future<Result<List<ForkRef>>> listForks({
    required String mainSessionId,
  }) async {
    throw UnimplementedError('listForks will be implemented by ChatForkMixin');
  }

  @override
  Future<Result<void>> deleteFork({required String forkId}) async {
    throw UnimplementedError('deleteFork will be implemented by ChatForkMixin');
  }

  String _summarizeRecommendations(RecommendationResult result) {
    final recs = result.recommendations;
    if (recs.isEmpty) return '【上一轮推荐】本轮未匹配到符合条件的导师。';
    final lines = <String>['【上一轮已为用户推荐以下导师】'];
    for (final r in recs.take(5)) {
      lines.add(
        '- ${r.name}（${r.university} ${r.college}，'
        '职称：${r.title}，'
        '研究方向：${r.researchFields.join('、')}，'
        '匹配度：${r.matchLevel.name}）'
        '推荐理由：${r.reason}',
      );
    }
    lines.add('后续追问可基于以上导师作答；用户若要新推荐会另行触发。');
    return lines.join('\n');
  }

  String _systemPrompt(String? professorId) {
    const base = '''
你是 SchoNavi 的导师咨询助手，帮助学生理解推荐结果、解答关于导师与升学的追问。
规则：
1. 基于（若有）【上下文导师】与对话历史回答；事实以公开资料为准，不确定就说明，不要编造具体数据、联系方式或录取结果。
2. 中文回答，可用 Markdown；简洁、友好、给可执行建议。
3. 涉及“是否适合/能否考上/录取概率”等不确定问题，给方法与建议，不打包票。''';

    if (professorId == null) return base;
    final professor = db.getProfessor(professorId);
    if (professor == null) return base;

    return '$base\n【上下文导师】${professor.name}（'
        '${professor.university} ${professor.college} ${professor.title}），'
        '研究方向：${professor.researchFields.join('、')}。'
        '${professor.bio ?? ''}';
  }
}
