import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/core/storage/local_store.dart';
import 'package:scho_navi/data/ai/ai_chat_repository.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/data/mock/mock_chat_repository.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';

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
  }) async {
    return Success(reply);
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) async* {
    yield reply;
  }
}

void main() {
  group('MockChatRepository fork CRUD', () {
    late MockChatRepository repo;
    late LocalChatHistoryStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      store = LocalChatHistoryStore(_MemStore());
      repo = MockChatRepository(MockDb(), historyStore: store);
    });

    test('forkSession 复制源历史到 forkId', () async {
      await store.save('s1', [
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          content: '想做CV',
          createdAt: DateTime(2026, 6, 27),
          relatedRecommendations: const [],
          status: ChatMessageStatus.done,
        ),
      ]);
      final prof = MockDb().allProfessors.first;
      final res = await repo.forkSession(
        sourceSessionId: 's1',
        professorId: prof.id,
      );
      expect(res, isA<Success<String>>());
      expect((await store.load((res as Success<String>).data))!.length, 1);
    });

    test('listForks 返回 fork', () async {
      await store.save('s1', [
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          content: '想做CV',
          createdAt: DateTime(2026, 6, 27),
          relatedRecommendations: const [],
          status: ChatMessageStatus.done,
        ),
      ]);
      final prof = MockDb().allProfessors.first;
      await repo.forkSession(sourceSessionId: 's1', professorId: prof.id);
      final forks = await repo.listForks(mainSessionId: 's1');
      expect(forks, isA<Success<List<dynamic>>>());
      expect((forks as Success<List<dynamic>>).data.length, 1);
    });
  });

  group('AiChatRepository fork CRUD via ChatForkMixin', () {
    late AiChatRepository repo;
    late LocalChatHistoryStore store;
    late MockDb db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = MockDb();
      store = LocalChatHistoryStore(_MemStore());
      repo = AiChatRepository(
        llm: _StubLlm('回答'),
        db: db,
        historyStore: store,
      );
    });

    test('forkSession 复制源历史到 forkId', () async {
      await store.save('s1', [
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          content: '想做CV',
          createdAt: DateTime(2026, 6, 27),
          relatedRecommendations: const [],
          status: ChatMessageStatus.done,
        ),
        ChatMessage(
          id: 'm2',
          role: ChatRole.assistant,
          content: '为你挑了导师',
          createdAt: DateTime(2026, 6, 27),
          relatedRecommendations: const [],
          status: ChatMessageStatus.done,
        ),
      ]);
      final prof = db.allProfessors.first;
      final res = await repo.forkSession(
        sourceSessionId: 's1',
        professorId: prof.id,
      );
      expect(res, isA<Success<String>>());
      final forkId = (res as Success<String>).data;
      expect(forkId, 'f_s1_${prof.id}');
      final forkHistory = await store.load(forkId);
      expect(forkHistory!.length, 2);
      expect(forkHistory[0].content, '想做CV');
    });

    test('同导师复用已有 fork 不新建', () async {
      await store.save('s1', [
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          content: '想做CV',
          createdAt: DateTime(2026, 6, 27),
          relatedRecommendations: const [],
          status: ChatMessageStatus.done,
        ),
      ]);
      final prof = db.allProfessors.first;
      final id1 = await repo.forkSession(
        sourceSessionId: 's1',
        professorId: prof.id,
      );
      final id2 = await repo.forkSession(
        sourceSessionId: 's1',
        professorId: prof.id,
      );
      expect((id2 as Success<String>).data, (id1 as Success<String>).data);
      final forks = await repo.listForks(mainSessionId: 's1');
      expect((forks as Success<List<dynamic>>).data.length, 1);
    });

    test('ForkRef 含导师信息', () async {
      await store.save('s1', [
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          content: '想做CV',
          createdAt: DateTime(2026, 6, 27),
          relatedRecommendations: const [],
          status: ChatMessageStatus.done,
        ),
      ]);
      final prof = db.allProfessors.first;
      await repo.forkSession(sourceSessionId: 's1', professorId: prof.id);
      final res = await repo.listForks(mainSessionId: 's1');
      final forks = (res as Success<List<dynamic>>).data;
      expect(forks[0].professorName, prof.name);
      expect(forks[0].university, prof.university);
    });

    test('loadHistory 未知 session 返回空', () async {
      final res = await repo.loadHistory(sessionId: 'unknown');
      expect((res as Success<List<ChatMessage>>).data, isEmpty);
    });

    test('deleteFork 后 listForks 不再含', () async {
      await store.save('s1', [
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          content: '想做CV',
          createdAt: DateTime(2026, 6, 27),
          relatedRecommendations: const [],
          status: ChatMessageStatus.done,
        ),
      ]);
      final prof = db.allProfessors.first;
      final forkId =
          (await repo.forkSession(
                sourceSessionId: 's1',
                professorId: prof.id,
              )
              as Success<String>)
          .data;
      await repo.deleteFork(forkId: forkId);
      expect(await repo.listForks(mainSessionId: 's1'), isA<Success<List<dynamic>>>());
      expect(((await repo.listForks(mainSessionId: 's1')) as Success<List<dynamic>>).data, isEmpty);
    });
  });
}
