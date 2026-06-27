import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/storage/local_store.dart';
import 'package:scho_navi/data/dto/chat_message_dto.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/fork_ref.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemLocalStore implements LocalStore {
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

ChatMessage _msg(String id, String content,
        {ChatRole role = ChatRole.assistant}) =>
    ChatMessage(
      id: id,
      role: role,
      content: content,
      createdAt: DateTime(2026, 6, 27),
      relatedRecommendations: const [],
      status: ChatMessageStatus.done,
    );

void main() {
  late LocalChatHistoryStore store;
  late _MemLocalStore backing;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backing = _MemLocalStore();
    store = LocalChatHistoryStore(backing);
  });

  group('消息持久化', () {
    test('save 后 load 回来', () async {
      await store.save('s1', [_msg('m1', 'hi'), _msg('m2', 'yo')]);
      final loaded = await store.load('s1');
      expect(loaded, isNotNull);
      expect(loaded!.length, 2);
      expect(loaded[0].content, 'hi');
      expect(loaded[1].content, 'yo');
    });

    test('load 未存过的 session 返回 null', () async {
      expect(await store.load('nope'), isNull);
    });

    test('save 覆盖旧内容', () async {
      await store.save('s1', [_msg('m1', 'old')]);
      await store.save('s1', [_msg('m1', 'new')]);
      final loaded = await store.load('s1');
      expect(loaded!.length, 1);
      expect(loaded[0].content, 'new');
    });
  });

  group('ForkRef 持久化', () {
    test('saveFork + listForks 按时间倒序', () async {
      await store.saveFork(ForkRef(
        forkId: 'f_s1_p1', mainSessionId: 's1', professorId: 'p1',
        professorName: '李', university: '清华', college: 'cs',
        createdAt: DateTime(2026, 6, 27, 10),
      ));
      await store.saveFork(ForkRef(
        forkId: 'f_s1_p2', mainSessionId: 's1', professorId: 'p2',
        professorName: '王', university: '北大', college: null,
        createdAt: DateTime(2026, 6, 27, 14),
      ));
      final forks = await store.listForks('s1');
      expect(forks.length, 2);
      expect(forks[0].forkId, 'f_s1_p2'); // 14:00 在前
      expect(forks[1].forkId, 'f_s1_p1');
    });

    test('findFork 命中已有', () async {
      final ref = ForkRef(
        forkId: 'f_s1_p1', mainSessionId: 's1', professorId: 'p1',
        professorName: '李', university: '清华', college: 'cs',
        createdAt: DateTime(2026, 6, 27),
      );
      await store.saveFork(ref);
      expect(await store.findFork('s1', 'p1'), isNotNull);
      expect(await store.findFork('s1', 'pX'), isNull);
    });

    test('deleteFork 仅删指定 fork', () async {
      await store.saveFork(ForkRef(
        forkId: 'f_s1_p1', mainSessionId: 's1', professorId: 'p1',
        professorName: '李', university: '清华', college: null,
        createdAt: DateTime(2026, 6, 27),
      ));
      await store.saveFork(ForkRef(
        forkId: 'f_s1_p2', mainSessionId: 's1', professorId: 'p2',
        professorName: '王', university: '北大', college: null,
        createdAt: DateTime(2026, 6, 27),
      ));
      await store.deleteFork('f_s1_p1');
      final forks = await store.listForks('s1');
      expect(forks.length, 1);
      expect(forks[0].forkId, 'f_s1_p2');
    });

    test('listForks 隔离不同主 session', () async {
      await store.saveFork(ForkRef(
        forkId: 'f_s1_p1', mainSessionId: 's1', professorId: 'p1',
        professorName: '李', university: '清华', college: null,
        createdAt: DateTime(2026, 6, 27),
      ));
      await store.saveFork(ForkRef(
        forkId: 'f_s2_p1', mainSessionId: 's2', professorId: 'p1',
        professorName: '李', university: '清华', college: null,
        createdAt: DateTime(2026, 6, 27),
      ));
      expect((await store.listForks('s1')).length, 1);
      expect((await store.listForks('s2')).length, 1);
    });

    test('deleteFork 同时删除 fork 消息历史', () async {
      await store.saveFork(ForkRef(
        forkId: 'f_s1_p1', mainSessionId: 's1', professorId: 'p1',
        professorName: '李', university: '清华', college: null,
        createdAt: DateTime(2026, 6, 27),
      ));
      await store.save('f_s1_p1', [_msg('m1', 'fork msg')]);
      expect(await store.load('f_s1_p1'), isNotNull);
      await store.deleteFork('f_s1_p1');
      expect(await store.load('f_s1_p1'), isNull);
    });
  });
}
