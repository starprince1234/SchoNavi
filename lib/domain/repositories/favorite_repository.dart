import '../entities/favorite_item.dart';

abstract interface class FavoriteRepository {
  List<FavoriteItem> list();
  Stream<List<FavoriteItem>> watch();
  bool isFavorite(String professorId);
  Future<void> add(FavoriteItem item);
  Future<void> remove(String professorId);

  /// 切换收藏状态，返回切换后的状态：true 表示已收藏。
  Future<bool> toggle(FavoriteItem item);
}
