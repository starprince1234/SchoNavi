/// 本地搜索历史快照。
class SearchHistoryItem {
  const SearchHistoryItem({
    required this.sessionId,
    required this.prompt,
    required this.createdAt,
    required this.summary,
    required this.researchInterests,
    required this.preferredLocations,
    required this.recommendationCount,
  });

  final String sessionId;
  final String prompt;
  final DateTime createdAt;
  final String summary;
  final List<String> researchInterests;
  final List<String> preferredLocations;
  final int recommendationCount;
}
