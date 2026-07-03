import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/core/storage/local_store.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/data/mock/mock_chat_repository.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';

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

void main() {
  final db = MockDb();
  SharedPreferences.setMockInitialValues({});
  final store = LocalChatHistoryStore(_MemStore());
  final repo = MockChatRepository(db, historyStore: store);

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
    expect(data.answer, contains(db.getProfessor('p_001')!.name));
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
    final repo = MockChatRepository(
      MockDb(),
      historyStore: store,
      streamChunkDelay: Duration.zero,
    );

    final chunks = await repo
        .streamReply(sessionId: 's_1', message: '为什么推荐他', professorId: 'p_001')
        .toList();

    expect(chunks.length, greaterThan(1));
    expect(chunks.join(), contains('依据'));
  });
}
