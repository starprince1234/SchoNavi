import 'dart:async';

import '../../core/storage/local_store.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../domain/entities/search_history_item.dart';
import '../../domain/repositories/history_repository.dart';

class LocalHistoryRepository implements HistoryRepository {
  LocalHistoryRepository(this._store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const String storageKey = 'search_history.v1';

  final LocalStore _store;
  final DateTime Function() _now;
  final StreamController<List<SearchHistoryItem>> _controller =
      StreamController<List<SearchHistoryItem>>.broadcast();

  @override
  List<SearchHistoryItem> list() => _readAll();

  @override
  Stream<List<SearchHistoryItem>> watch() async* {
    yield list();
    yield* _controller.stream;
  }

  @override
  Future<void> addFromResult({
    required String prompt,
    required RecommendationResult result,
  }) async {
    final item = SearchHistoryItem(
      sessionId: result.sessionId,
      prompt: prompt,
      createdAt: _now(),
      summary: _buildSummary(result),
      researchInterests: result.queryUnderstanding.researchInterests,
      preferredLocations: result.queryUnderstanding.preferredLocations,
      recommendationCount: result.recommendations.length,
    );
    final items = [
      item,
      ...list().where((current) => current.sessionId != result.sessionId),
    ]..sort(_byNewest);
    await _writeAll(items);
  }

  @override
  Future<void> remove(String sessionId) async {
    final items = list()
        .where((current) => current.sessionId != sessionId)
        .toList();
    await _writeAll(items);
  }

  @override
  Future<void> clear() => _writeAll(const []);

  void dispose() => _controller.close();

  List<SearchHistoryItem> _readAll() {
    final raw = _store.getJsonList(storageKey);
    if (raw == null) return const [];

    final items = <SearchHistoryItem>[];
    for (final entry in raw) {
      final item = _parseItem(entry);
      if (item != null) items.add(item);
    }
    items.sort(_byNewest);
    return items;
  }

  SearchHistoryItem? _parseItem(Object? entry) {
    if (entry is! Map) return null;
    final json = Map<String, dynamic>.from(entry);
    final sessionId = json['session_id'];
    final prompt = json['prompt'];
    final summary = json['summary'];
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
    final count = json['recommendation_count'];

    if (sessionId is! String ||
        sessionId.isEmpty ||
        prompt is! String ||
        prompt.isEmpty ||
        summary is! String ||
        createdAt == null ||
        count is! int) {
      return null;
    }

    return SearchHistoryItem(
      sessionId: sessionId,
      prompt: prompt,
      createdAt: createdAt,
      summary: summary,
      researchInterests:
          (json['research_interests'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      preferredLocations:
          (json['preferred_locations'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      recommendationCount: count,
    );
  }

  Future<void> _writeAll(List<SearchHistoryItem> items) async {
    await _store.setJsonList(
      storageKey,
      items.map(_toJson).toList(growable: false),
    );
    _controller.add(List<SearchHistoryItem>.unmodifiable(items));
  }

  Map<String, dynamic> _toJson(SearchHistoryItem item) => <String, dynamic>{
    'session_id': item.sessionId,
    'prompt': item.prompt,
    'created_at': item.createdAt.toIso8601String(),
    'summary': item.summary,
    'research_interests': item.researchInterests,
    'preferred_locations': item.preferredLocations,
    'recommendation_count': item.recommendationCount,
  };

  static String _buildSummary(RecommendationResult result) {
    final interests = result.queryUnderstanding.researchInterests;
    final locations = result.queryUnderstanding.preferredLocations;
    final parts = <String>[
      if (interests.isNotEmpty) '方向：${interests.join('、')}',
      if (locations.isNotEmpty) '地区：${locations.join('、')}',
    ];
    return parts.isEmpty ? '未识别出明确方向，可重推优化条件' : parts.join(' / ');
  }

  static int _byNewest(SearchHistoryItem a, SearchHistoryItem b) =>
      b.createdAt.compareTo(a.createdAt);
}
