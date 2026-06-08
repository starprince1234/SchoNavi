import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/storage/shared_preferences_local_store.dart';
import 'package:scho_navi/data/local/local_favorite_repository.dart';
import 'package:scho_navi/domain/entities/favorite_item.dart';

void main() {
  late SharedPreferencesLocalStore store;
  late LocalFavoriteRepository repo;

  FavoriteItem item(
    String id, {
    DateTime? favoritedAt,
    String? homepageUrl,
  }) => FavoriteItem(
    professorId: id,
    name: '张三$id',
    university: '上海交通大学',
    college: '电子信息与电气工程学院',
    title: '教授',
    researchFields: const ['医学影像'],
    homepageUrl: homepageUrl,
    favoritedAt: favoritedAt ?? DateTime(2026, 6, 8, 10),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    store = SharedPreferencesLocalStore(prefs);
    repo = LocalFavoriteRepository(store);
  });

  tearDown(() => repo.dispose());

  test('add/remove/isFavorite/list works', () async {
    await repo.add(item('p_001'));
    expect(repo.isFavorite('p_001'), isTrue);
    expect(repo.list().single.professorId, 'p_001');

    await repo.remove('p_001');
    expect(repo.isFavorite('p_001'), isFalse);
    expect(repo.list(), isEmpty);
  });

  test('toggle returns new state', () async {
    expect(await repo.toggle(item('p_001')), isTrue);
    expect(repo.isFavorite('p_001'), isTrue);

    expect(await repo.toggle(item('p_001')), isFalse);
    expect(repo.isFavorite('p_001'), isFalse);
  });

  test('newest favorites are listed first and duplicate id is replaced', () async {
    await repo.add(item('p_001', favoritedAt: DateTime(2026, 6, 8, 10)));
    await repo.add(item('p_002', favoritedAt: DateTime(2026, 6, 8, 11)));
    await repo.add(
      item(
        'p_001',
        favoritedAt: DateTime(2026, 6, 8, 12),
        homepageUrl: 'https://example.edu.cn/new',
      ),
    );

    final items = repo.list();
    expect(items.map((e) => e.professorId), ['p_001', 'p_002']);
    expect(items.first.homepageUrl, 'https://example.edu.cn/new');
  });

  test('watch emits current and changed lists', () async {
    final events = <List<FavoriteItem>>[];
    final sub = repo.watch().listen(events.add);
    addTearDown(sub.cancel);

    await Future<void>.delayed(Duration.zero);
    expect(events.single, isEmpty);

    await repo.add(item('p_001'));
    await Future<void>.delayed(Duration.zero);

    expect(events.last.single.professorId, 'p_001');
  });

  test('bad json entries are ignored instead of crashing', () async {
    await store.setJsonList(LocalFavoriteRepository.storageKey, <dynamic>[
      <String, dynamic>{'bad': true},
      'not a map',
      <String, dynamic>{
        'professor_id': 'p_001',
        'name': '张三',
        'university': '上海交通大学',
        'college': '电子信息与电气工程学院',
        'title': '教授',
        'research_fields': ['医学影像'],
        'favorited_at': '2026-06-08T10:00:00.000',
      },
    ]);

    final items = repo.list();
    expect(items, hasLength(1));
    expect(items.single.professorId, 'p_001');
  });
}
