import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'local_store.dart';

/// [LocalStore] 的 SharedPreferences 实现。
/// JSON 对象/数组统一经 [jsonEncode] 存为字符串，读时容错解码。
class SharedPreferencesLocalStore implements LocalStore {
  SharedPreferencesLocalStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  @override
  List<dynamic>? getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setJsonList(String key, List<dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  @override
  bool containsKey(String key) => _prefs.containsKey(key);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  @override
  Future<void> clear() => _prefs.clear();
}
