import 'dart:async';

import '../../core/storage/local_store.dart';
import '../../domain/entities/favorite_item.dart';
import '../../domain/repositories/favorite_repository.dart';

class LocalFavoriteRepository implements FavoriteRepository {
  LocalFavoriteRepository(this._store);

  static const String storageKey = 'favorites.v1';

  final LocalStore _store;
  final StreamController<List<FavoriteItem>> _controller =
      StreamController<List<FavoriteItem>>.broadcast();

  @override
  List<FavoriteItem> list() => _readAll();

  @override
  Stream<List<FavoriteItem>> watch() async* {
    yield list();
    yield* _controller.stream;
  }

  @override
  bool isFavorite(String professorId) =>
      list().any((item) => item.professorId == professorId);

  @override
  Future<void> add(FavoriteItem item) async {
    final items = [
      item,
      ...list().where((current) => current.professorId != item.professorId),
    ]..sort(_byNewest);
    await _writeAll(items);
  }

  @override
  Future<void> remove(String professorId) async {
    final items = list()
        .where((current) => current.professorId != professorId)
        .toList();
    await _writeAll(items);
  }

  @override
  Future<bool> toggle(FavoriteItem item) async {
    if (isFavorite(item.professorId)) {
      await remove(item.professorId);
      return false;
    }
    await add(item);
    return true;
  }

  void dispose() => _controller.close();

  List<FavoriteItem> _readAll() {
    final raw = _store.getJsonList(storageKey);
    if (raw == null) return const [];

    final items = <FavoriteItem>[];
    for (final entry in raw) {
      final item = _parseItem(entry);
      if (item != null) items.add(item);
    }
    items.sort(_byNewest);
    return items;
  }

  FavoriteItem? _parseItem(Object? entry) {
    if (entry is! Map) return null;
    final json = Map<String, dynamic>.from(entry);
    final professorId = json['professor_id'];
    final name = json['name'];
    final university = json['university'];
    final college = json['college'];
    final title = json['title'];
    final favoritedAt = DateTime.tryParse(
      json['favorited_at'] as String? ?? '',
    );

    if (professorId is! String ||
        professorId.isEmpty ||
        name is! String ||
        name.isEmpty ||
        university is! String ||
        college is! String ||
        title is! String ||
        favoritedAt == null) {
      return null;
    }

    return FavoriteItem(
      professorId: professorId,
      name: name,
      university: university,
      college: college,
      title: title,
      researchFields:
          (json['research_fields'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      homepageUrl: json['homepage_url'] as String?,
      favoritedAt: favoritedAt,
    );
  }

  Future<void> _writeAll(List<FavoriteItem> items) async {
    await _store.setJsonList(
      storageKey,
      items.map(_toJson).toList(growable: false),
    );
    _controller.add(List<FavoriteItem>.unmodifiable(items));
  }

  Map<String, dynamic> _toJson(FavoriteItem item) => <String, dynamic>{
    'professor_id': item.professorId,
    'name': item.name,
    'university': item.university,
    'college': item.college,
    'title': item.title,
    'research_fields': item.researchFields,
    if (item.homepageUrl != null) 'homepage_url': item.homepageUrl,
    'favorited_at': item.favoritedAt.toIso8601String(),
  };

  static int _byNewest(FavoriteItem a, FavoriteItem b) =>
      b.favoritedAt.compareTo(a.favoritedAt);
}
