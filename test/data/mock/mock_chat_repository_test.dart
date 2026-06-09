import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/mock/mock_chat_repository.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';

void main() {
  final db = MockDb();
  final repo = MockChatRepository(db);

  Future<ChatResult> ask(String message, {String? professorId}) async {
    final res = await repo.sendMessage(
      sessionId: 's_1',
      message: message,
      professorId: professorId,
    );
    return (res as Success<ChatResult>).data;
  }

  test('回显 sessionId', () async {
    final data = await ask('随便聊聊');
    expect(data.sessionId, 's_1');
  });

  test('「为什么」意图：给出理由、不附带推荐卡片', () async {
    final data = await ask('为什么推荐他', professorId: 'p_001');
    expect(data.answer, contains('依据'));
    expect(data.answer, contains('张三'));
    expect(data.relatedRecommendations, isEmpty);
  });

  test('「相似导师」意图：返回相关推荐且排除锚定导师本身', () async {
    final data = await ask('有没有相似的导师', professorId: 'p_001');
    expect(data.relatedRecommendations, isNotEmpty);
    expect(
      data.relatedRecommendations.any((r) => r.professorId == 'p_001'),
      isFalse,
    );
  });

  test('「只看某地」意图：返回该地区推荐', () async {
    final data = await ask('只看北京的导师');
    expect(data.relatedRecommendations, isNotEmpty);
    expect(data.answer, contains('北京'));
  });

  test('「换方向」意图：按新方向重新推荐', () async {
    final data = await ask('换成自然语言处理方向');
    expect(data.relatedRecommendations, isNotEmpty);
    expect(data.answer, contains('自然语言处理'));
  });

  test('兜底：无明确意图返回澄清问题', () async {
    final data = await ask('嗯');
    expect(data.relatedRecommendations, isEmpty);
    expect(data.answer, contains('补充'));
  });

  test('streamReply 逐段 emit 且可拼回完整答案', () async {
    final repo = MockChatRepository(MockDb(), streamChunkDelay: Duration.zero);

    final chunks = await repo
        .streamReply(sessionId: 's_1', message: '为什么推荐他', professorId: 'p_001')
        .toList();

    expect(chunks.length, greaterThan(1));
    expect(chunks.join(), contains('依据'));
  });
}
