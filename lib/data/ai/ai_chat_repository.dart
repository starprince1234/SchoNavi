import 'dart:async';

import '../../core/ai/llm_client.dart';
import '../../core/result/result.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_result.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../domain/repositories/chat_repository.dart';
import '../chat_fork_mixin.dart';
import '../local/chat_history_store.dart';
import '../mock/mock_db.dart';

class AiChatRepository extends ChatRepository with ChatForkMixin {
  AiChatRepository({
    required this.llm,
    required this.db,
    required this.historyStore,
  });

  final LlmClient llm;
  @override
  final MockDb db;

  @override
  final ChatHistoryStore historyStore;
  final Map<String, List<LlmMessage>> _history = {};
  final Map<String, List<LlmMessage>> _systemContext = {};

  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) async {
    _ensureHistoryLoaded(sessionId);
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
      messages: _buildMessages(sessionId, professorId, history),
    );

    if (res is Failure<String>) return Failure(res.error);

    final answer = (res as Success<String>).data;
    history.add(LlmMessage('assistant', answer));
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
        _ensureHistoryLoaded(sessionId);
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
              .stream(messages: _buildMessages(sessionId, professorId, history))
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
    _ensureHistoryLoaded(sessionId);
    final history = _history.putIfAbsent(sessionId, () => []);
    history.add(LlmMessage('user', userPrompt));
    // 推荐摘要以 system 角色注入后续 LLM 调用，不进可见消息流、不落盘。
    final ctx = _systemContext.putIfAbsent(sessionId, () => []);
    ctx
      ..clear()
      ..add(LlmMessage('system', _summarizeRecommendations(result)));
  }

  @override
  Future<Result<String>> forkSession({
    required String sourceSessionId,
    required String professorId,
  }) async {
    final res = await super.forkSession(
      sourceSessionId: sourceSessionId,
      professorId: professorId,
    );
    if (res is Success<String>) {
      // 同进程内复制 LLM 上下文（纯内存），让 fork 内追问能延续对话与推荐摘要。
      final forkId = res.data;
      final srcHistory = _history[sourceSessionId];
      _history[forkId] = srcHistory != null ? [...srcHistory] : [];
      final srcCtx = _systemContext[sourceSessionId];
      _systemContext[forkId] = srcCtx != null ? [...srcCtx] : [];
    }
    return res;
  }

  @override
  Future<void> persistMessages(
    String sessionId,
    List<ChatMessage> messages,
  ) async {
    await historyStore.save(sessionId, messages);
  }

  // ---- helpers ----

  /// 拼接发给 LLM 的完整消息序列：基础 system prompt + 推荐摘要（system）+ 对话历史。
  List<LlmMessage> _buildMessages(
    String sessionId,
    String? professorId,
    List<LlmMessage> history,
  ) {
    return [
      LlmMessage('system', _systemPrompt(professorId)),
      ...?_systemContext[sessionId],
      ...history,
    ];
  }

  void _ensureHistoryLoaded(String sessionId) {
    // _history 纯内存：可见历史由 persistMessages 落盘，LLM 上下文不落盘。
    _history.putIfAbsent(sessionId, () => []);
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
