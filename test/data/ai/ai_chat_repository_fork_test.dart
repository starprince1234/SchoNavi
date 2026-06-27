import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/core/storage/local_store.dart';
import 'package:scho_navi/data/ai/ai_chat_repository.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late AiChatRepository repo;
  late LocalChatHistoryStore store;
  late MockDb db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = MockDb();
    store = LocalChatHistoryStore(_MemStore());
    repo = AiChatRepository(llm: _StubLlm('回答'), db: db, historyStore: store);
  });

  group('AiChatRepository 持久化改造（fork 4 方法见 Task 6 mixin）', () {
    test('streamReply 完成后历史写入 store', () async {
      await repo.streamReply(
        sessionId: 's1',
        message: '为什么推荐他',
        professorId: null,
      ).last;
      final saved = await store.load('s1');
      expect(saved, isNotNull);
      expect(saved!.length, greaterThanOrEqualTo(2)); // user + assistant
      expect(saved.any((m) => m.content == '回答'), isTrue);
    });

    test('新进程读 store 回填内存历史（_ensureHistoryLoaded）', () async {
      // 先一个 repo 写入
      await repo.streamReply(
        sessionId: 's1',
        message: '问1',
        professorId: null,
      ).last;
      // 模拟新进程：新建 repo（内存 _history 空），再 streamReply 时应从 store 回填
      final repo2 = AiChatRepository(
        llm: _StubLlm('回答2'),
        db: db,
        historyStore: store,
      );
      await repo2.streamReply(
        sessionId: 's1',
        message: '问2',
        professorId: null,
      ).last;
      final saved = await store.load('s1');
      // 含「问1」回填 + 「问2」追加
      expect(saved!.any((m) => m.content == '问1'), isTrue);
      expect(saved.any((m) => m.content == '问2'), isTrue);
    });

    test('seedRecommendationTurn 前会先回填持久化历史，避免覆盖', () async {
      // 1. 已有持久化历史
      await repo.streamReply(
        sessionId: 's1',
        message: '问 A',
        professorId: null,
      ).last;

      // 2. 模拟新进程：内存 _history 为空
      final repo2 = AiChatRepository(
        llm: _StubLlm('回答2'),
        db: db,
        historyStore: store,
      );

      const result = RecommendationResult(
        sessionId: 's1',
        queryUnderstanding: QueryUnderstanding(
          researchInterests: ['AI'],
          preferredLocations: [],
          preferredUniversities: [],
          uncertainties: [],
        ),
        recommendations: [
          Recommendation(
            professorId: 'p1',
            name: '张教授',
            university: '清华',
            college: '计算机',
            title: '教授',
            researchFields: ['AI'],
            matchLevel: MatchLevel.high,
            reason: '方向匹配',
            limitations: [],
          ),
        ],
        followUpQuestions: [],
      );

      await repo2.seedRecommendationTurn(
        sessionId: 's1',
        userPrompt: '帮我推荐导师',
        result: result,
      );

      final saved = await store.load('s1');
      expect(saved, isNotNull);
      final contents = saved!.map((m) => m.content).toList();
      // 既有历史与新 seed 都应保留
      expect(
        contents,
        contains('问 A'),
        reason: '既有 persistent history 不应被 seedRecommendationTurn 覆盖',
      );
      expect(contents, contains('帮我推荐导师'));
      expect(contents.any((c) => c.contains('张教授')), isTrue);
      expect(contents.length, greaterThanOrEqualTo(4));
    });
  });
}

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
