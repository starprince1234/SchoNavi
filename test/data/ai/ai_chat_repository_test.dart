import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_chat_repository.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';

class _RecordingLlm implements LlmClient {
  _RecordingLlm(this.reply);

  String reply;
  final List<List<LlmMessage>> calls = [];

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    calls.add(messages);
    return Success(reply);
  }
}

class _FailLlm implements LlmClient {
  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    return const Failure(ServerException());
  }
}

void main() {
  test('answer/sessionId pass through and no embedded cards', () async {
    final repo = AiChatRepository(llm: _RecordingLlm('你好'), db: MockDb());

    final res = await repo.sendMessage(sessionId: 's1', message: '在吗');

    final data = (res as Success<ChatResult>).data;
    expect(data.answer, '你好');
    expect(data.sessionId, 's1');
    expect(data.relatedRecommendations, isEmpty);
  });

  test('second call includes previous history', () async {
    final llm = _RecordingLlm('A');
    final repo = AiChatRepository(llm: llm, db: MockDb());

    await repo.sendMessage(sessionId: 's1', message: '问题一');
    llm.reply = 'B';
    await repo.sendMessage(sessionId: 's1', message: '问题二');

    final contents = llm.calls.last.map((m) => m.content).toList();
    expect(contents, containsAll(['问题一', 'A', '问题二']));
  });

  test('professorId injects professor context into system prompt', () async {
    final llm = _RecordingLlm('ok');
    final repo = AiChatRepository(llm: llm, db: MockDb());

    await repo.sendMessage(
      sessionId: 's1',
      message: '为什么推荐他',
      professorId: 'p_001',
    );

    final system = llm.calls.last.first;
    expect(system.role, 'system');
    expect(system.content, contains('张三'));
  });

  test('regenerate does not duplicate repeated last user message', () async {
    final llm = _RecordingLlm('A1');
    final repo = AiChatRepository(llm: llm, db: MockDb());

    await repo.sendMessage(sessionId: 's1', message: '同一个问题');
    llm.reply = 'A2';
    await repo.sendMessage(sessionId: 's1', message: '同一个问题');

    final userCount = llm.calls.last
        .where((m) => m.role == 'user' && m.content == '同一个问题')
        .length;
    expect(userCount, 1);
  });

  test('LLM failure passes through', () async {
    final repo = AiChatRepository(llm: _FailLlm(), db: MockDb());

    final res = await repo.sendMessage(sessionId: 's1', message: 'x');

    expect((res as Failure).error, isA<ServerException>());
  });
}
