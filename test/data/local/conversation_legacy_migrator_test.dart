import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/storage/local_store.dart';
import 'package:scho_navi/data/local/conversation_database.dart';
import 'package:scho_navi/data/local/conversation_legacy_migrator.dart';
import 'package:scho_navi/data/local/drift_conversation_store.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/data/local/local_history_repository.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/fork_ref.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';

class _MemoryLocalStore implements LocalStore {
  final Map<String, Object?> values = {};

  @override
  Future<void> clear() async => values.clear();
  @override
  bool containsKey(String key) => values.containsKey(key);
  @override
  bool? getBool(String key) => values[key] as bool?;
  @override
  Map<String, dynamic>? getJson(String key) =>
      values[key] as Map<String, dynamic>?;
  @override
  List<dynamic>? getJsonList(String key) => values[key] as List<dynamic>?;
  @override
  String? getString(String key) => values[key] as String?;
  @override
  Future<void> remove(String key) async => values.remove(key);
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async =>
      values[key] = value;
  @override
  Future<void> setJsonList(String key, List<dynamic> value) async =>
      values[key] = value;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}

ChatMessage _message(
  String id,
  ChatRole role,
  String content, {
  ChatMessageKind kind = ChatMessageKind.conversation,
  List<Recommendation> recommendations = const [],
}) => ChatMessage(
  id: id,
  role: role,
  content: content,
  createdAt: DateTime.utc(2026, 6, 27),
  relatedRecommendations: recommendations,
  status: ChatMessageStatus.done,
  kind: kind,
);

void main() {
  test('旧消息、fork 与 alias 单事务导入且迁移幂等', () async {
    final database = ConversationDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DriftConversationStore(database);
    final legacy = _MemoryLocalStore();
    final oldChat = LocalChatHistoryStore(legacy);
    final recommendation = Recommendation(
      professorId: 'p_001',
      name: '张三',
      university: '测试大学',
      college: '计算机学院',
      title: '教授',
      researchFields: const ['计算机视觉'],
      matchLevel: MatchLevel.high,
      reason: '方向匹配',
      limitations: const [],
    );
    final prefix = [
      _message('legacy-u1', ChatRole.user, '推荐导师'),
      _message(
        'legacy-a1',
        ChatRole.assistant,
        '推荐结果',
        kind: ChatMessageKind.recommendation,
        recommendations: [recommendation],
      ),
    ];
    await legacy.setJsonList(LocalHistoryRepository.storageKey, [
      {'type': 'mentor', 'session_id': 'legacy-main', 'prompt': '推荐导师'},
      {
        'type': 'competition',
        'session_id': 'legacy-competition',
        'prompt': '推荐竞赛',
      },
    ]);
    await oldChat.save('legacy-main', prefix);
    await oldChat.save('legacy-fork', [
      ...prefix,
      _message('legacy-u2', ChatRole.user, '详细介绍张三'),
      _message('legacy-a2', ChatRole.assistant, '张三的详细信息'),
    ]);
    await oldChat.saveFork(
      ForkRef(
        forkId: 'legacy-fork',
        mainSessionId: 'legacy-main',
        professorId: 'p_001',
        professorName: '张三',
        university: '测试大学',
        college: '计算机学院',
        createdAt: DateTime.utc(2026, 6, 27),
      ),
    );

    final migrator = ConversationLegacyMigrator(
      store: store,
      legacyStore: legacy,
    );
    await migrator.migrateIfNeeded();

    final root = await store.getSession('legacy-main');
    final fork = await store.getSession('legacy-fork');
    expect(root, isNotNull);
    expect(fork, isNotNull);
    expect(fork!.sourceTurnId, isNotNull);
    expect(fork.legacyContextIncomplete, isFalse);
    final forkAggregate = await store.loadAggregate(fork.id);
    expect(forkAggregate!.messages.map((message) => message.content), [
      '详细介绍张三',
      '张三的详细信息',
    ]);
    final forkContext = await store.loadAggregate(
      fork.id,
      includeInherited: true,
    );
    expect(forkContext!.messages.map((message) => message.content), [
      '推荐导师',
      '推荐结果',
      '详细介绍张三',
      '张三的详细信息',
    ]);
    expect(legacy.containsKey('chat_history_legacy-main'), isFalse);
    expect(legacy.containsKey('chat_history_legacy-fork'), isFalse);
    expect(legacy.containsKey('chat_forks'), isFalse);
    expect(legacy.getJsonList(LocalHistoryRepository.storageKey), hasLength(1));

    await ConversationLegacyMigrator(
      store: store,
      legacyStore: legacy,
    ).migrateIfNeeded();
    expect(await store.listSessions(), hasLength(1));
    expect(await store.listForks(root!.id), hasLength(1));
  });
}
