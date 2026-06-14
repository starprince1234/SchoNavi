import 'dart:async';

import '../../domain/entities/recommendation_result.dart';
import '../../domain/entities/search_history_item.dart';
import '../../domain/repositories/history_repository.dart';

/// 内存搜索历史仓储，模拟后端历史接口。
class MockHistoryRepository implements HistoryRepository {
  MockHistoryRepository({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final List<SearchHistoryItem> _items = [];
  final StreamController<List<SearchHistoryItem>> _controller =
      StreamController<List<SearchHistoryItem>>.broadcast();

  @override
  List<SearchHistoryItem> list() => List.unmodifiable(_items);

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
    await Future<void>.delayed(const Duration(milliseconds: 150));
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
      ..._items.where((current) => current.sessionId != result.sessionId),
    ]..sort(_byNewest);
    _items
      ..clear()
      ..addAll(items);
    _controller.add(list());
  }

  @override
  Future<void> remove(String sessionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _items.removeWhere((current) => current.sessionId == sessionId);
    _controller.add(list());
  }

  @override
  Future<void> clear() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _items.clear();
    _controller.add(list());
  }

  void dispose() => _controller.close();

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
