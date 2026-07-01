import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/storage/local_store.dart';
import 'package:scho_navi/core/storage/shared_preferences_local_store.dart';

void main() {
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    store = SharedPreferencesLocalStore(prefs);
  });

  test('string 往返；缺失返回 null', () async {
    expect(store.getString('k'), isNull);
    await store.setString('k', 'v');
    expect(store.getString('k'), 'v');
  });

  test('bool 往返（首启标记场景）', () async {
    expect(store.getBool('seenOnboarding'), isNull);
    await store.setBool('seenOnboarding', true);
    expect(store.getBool('seenOnboarding'), true);
  });

  test('json 对象往返（用户信息场景）', () async {
    await store.setJson('user', <String, dynamic>{'id': 'u1', 'isGuest': true});
    expect(store.getJson('user'), <String, dynamic>{
      'id': 'u1',
      'isGuest': true,
    });
  });

  test('json 数组往返（收藏/历史场景）', () async {
    await store.setJsonList('favs', <dynamic>[
      <String, dynamic>{'professorId': 'p_001'},
      <String, dynamic>{'professorId': 'p_002'},
    ]);
    final list = store.getJsonList('favs');
    expect(list, hasLength(2));
    expect((list!.first as Map)['professorId'], 'p_001');
  });

  test('损坏/缺失的 json 返回 null 而非抛出', () async {
    expect(store.getJson('missing'), isNull);
    expect(store.getJsonList('missing'), isNull);
    await store.setString('notJson', '{ this is not json');
    expect(store.getJson('notJson'), isNull);
    expect(store.getJsonList('notJson'), isNull);
  });

  test('remove 删除单键', () async {
    await store.setString('k', 'v');
    await store.remove('k');
    expect(store.getString('k'), isNull);
    expect(store.containsKey('k'), isFalse);
  });

  test('clear 清空全部', () async {
    await store.setString('a', '1');
    await store.setBool('b', true);
    await store.clear();
    expect(store.containsKey('a'), isFalse);
    expect(store.containsKey('b'), isFalse);
  });
}
