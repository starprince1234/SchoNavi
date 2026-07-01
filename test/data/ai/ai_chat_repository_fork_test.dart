import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/core/storage/local_store.dart';
import 'package:scho_navi/data/ai/ai_chat_repository.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingLlm implements LlmClient {
  _RecordingLlm(this.reply);
  final String reply;
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

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) async* {
    calls.add(messages);
    yield reply;
  }
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
  late LocalChatHistoryStore store;
  late MockDb db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = MockDb();
    store = LocalChatHistoryStore(_MemStore());
  });

  group('AiChatRepository 内存上下文（_history/_systemContext 不落盘）', () {
    test('streamReply 在同进程内累积对话历史，供后续轮 LLM 调用看到', () async {
      final llm = _RecordingLlm('回答');
      final r = AiChatRepository(llm: llm, db: db, historyStore: store);
      await r.streamReply(sessionId: 's1', message: '为什么推荐他').last;
      await r.streamReply(sessionId: 's1', message: '追问').last;

      // 第二次调用的 LLM 消息应含第一轮的 user + assistant。
      final contents = llm.calls.last
          .map((m) => '${m.role}:${m.content}')
          .toList();
      expect(
        contents,
        containsAllInOrder(['user:为什么推荐他', 'assistant:回答', 'user:追问']),
      );
      // repo 不再写 store（可见历史由 chat_provider 经 persistMessages 落盘）。
      expect(await store.load('s1'), isNull);
    });

    test('seedRecommendationTurn 把摘要注入 system 上下文，不写可见历史', () async {
      final llm = _RecordingLlm('回答');
      final r = AiChatRepository(llm: llm, db: db, historyStore: store);

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

      await r.seedRecommendationTurn(
        sessionId: 's1',
        userPrompt: '帮我推荐导师',
        result: result,
      );
      await r.streamReply(sessionId: 's1', message: '第一位的研究方向').last;

      final messages = llm.calls.last;
      // user 提问进对话历史（user 角色）。
      final nonSystem = messages
          .where((m) => m.role != 'system')
          .map((m) => '${m.role}:${m.content}')
          .toList();
      expect(nonSystem, containsAllInOrder(['user:帮我推荐导师', 'user:第一位的研究方向']));
      // 推荐摘要进 system 角色，不进可见对话历史。
      final systemContent = messages
          .where((m) => m.role == 'system')
          .map((m) => m.content)
          .join('\n');
      expect(systemContent, contains('张教授'));
      expect(systemContent, contains('【上一轮已为用户推荐以下导师】'));
      expect(
        nonSystem,
        everyElement(isNot(contains('【上一轮已为用户推荐以下导师】'))),
        reason: '摘要不应作为可见消息泄漏',
      );
      // seed 不写 store。
      expect(await store.load('s1'), isNull);
    });

    test('persistMessages 落盘可见消息，loadHistory 原样读回（带卡片、kind）', () async {
      final r = AiChatRepository(
        llm: _StubLlm('回答'),
        db: db,
        historyStore: store,
      );
      final now = DateTime(2026, 6, 27);
      final messages = <ChatMessage>[
        ChatMessage(
          id: 'm0',
          role: ChatRole.user,
          content: '想做CV',
          createdAt: now,
          relatedRecommendations: const [],
          status: ChatMessageStatus.done,
          kind: ChatMessageKind.conversation,
        ),
        ChatMessage(
          id: 'm1',
          role: ChatRole.assistant,
          content: '为你挑了 1 位合适的导师',
          createdAt: now,
          relatedRecommendations: [
            Recommendation(
              professorId: 'p1',
              name: '张教授',
              university: '清华',
              college: '计算机',
              title: '教授',
              researchFields: const ['CV'],
              matchLevel: MatchLevel.high,
              reason: '方向匹配',
              limitations: const [],
            ),
          ],
          status: ChatMessageStatus.done,
          kind: ChatMessageKind.recommendation,
        ),
      ];
      await r.persistMessages('s1', messages);
      final loaded = await store.load('s1');
      expect(loaded, isNotNull);
      expect(loaded!.length, 2);
      expect(loaded[1].kind, ChatMessageKind.recommendation);
      expect(loaded[1].relatedRecommendations, isNotEmpty);
      expect(loaded[1].relatedRecommendations.first.name, '张教授');
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
