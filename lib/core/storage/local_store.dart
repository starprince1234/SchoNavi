/// 本地键值持久化抽象（主设计 §6.3）。MVP 由 SharedPreferences 实现，
/// 后续可换 Hive。收藏 / 历史 / 首启标记 / 登录 token / 用户信息均经此存取。
///
/// 读方法同步返回（实现层在初始化后持有缓存）；写方法异步。
/// 缺失或解析失败一律返回 null，绝不抛出，便于上层降级到「暂无信息」。
abstract interface class LocalStore {
  String? getString(String key);
  Future<void> setString(String key, String value);

  bool? getBool(String key);
  Future<void> setBool(String key, bool value);

  /// 读/写一个 JSON 对象（内部以 jsonEncode 存为字符串）。
  Map<String, dynamic>? getJson(String key);
  Future<void> setJson(String key, Map<String, dynamic> value);

  /// 读/写一个 JSON 数组（收藏列表 / 历史列表用）。
  List<dynamic>? getJsonList(String key);
  Future<void> setJsonList(String key, List<dynamic> value);

  bool containsKey(String key);
  Future<void> remove(String key);
  Future<void> clear();
}
