import 'dart:async';

import '../../domain/entities/favorite_item.dart';
import '../../domain/repositories/favorite_repository.dart';

/// 内存收藏仓储，模拟后端收藏接口。
class MockFavoriteRepository implements FavoriteRepository {
  MockFavoriteRepository();

  final List<FavoriteItem> _items = [];
  final StreamController<List<FavoriteItem>> _controller =
      StreamController<List<FavoriteItem>>.broadcast();

  @override
  List<FavoriteItem> list() => List.unmodifiable(_items);

  @override
  Stream<List<FavoriteItem>> watch() async* {
    yield list();
    yield* _controller.stream;
  }

  @override
  bool isFavorite(String professorId) =>
      _items.any((item) => item.professorId == professorId);

  @override
  Future<void> add(FavoriteItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final items = [
      item,
      ..._items.where((current) => current.professorId != item.professorId),
    ]..sort(_byNewest);
    _items
      ..clear()
      ..addAll(items);
    _controller.add(list());
  }

  @override
  Future<void> remove(String professorId) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _items.removeWhere((current) => current.professorId == professorId);
    _controller.add(list());
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

  static int _byNewest(FavoriteItem a, FavoriteItem b) =>
      b.favoritedAt.compareTo(a.favoritedAt);
}
