import 'dart:async';

import '../../core/ai/llm_client.dart';
import '../../core/result/result.dart';
import '../../domain/entities/chat_result.dart';
import '../../domain/repositories/chat_repository.dart';
import '../mock/mock_db.dart';

class AiChatRepository implements ChatRepository {
  AiChatRepository({required this.llm, required this.db});

  final LlmClient llm;
  final MockDb db;
  final Map<String, List<LlmMessage>> _history = {};

  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) async {
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
      onListen: () {
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
                onDone: () {
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
