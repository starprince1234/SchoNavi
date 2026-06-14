/// 竞赛推荐卡片实体。
class RecommendedCompetition {
  const RecommendedCompetition({
    required this.id,
    required this.name,
    required this.category,
    required this.level,
    required this.tags,
    required this.teamSize,
    required this.signupTime,
    required this.contestTime,
    required this.format,
    required this.organizer,
    required this.officialUrl,
    required this.reason,
    required this.preparationTips,
    required this.limitations,
    required this.matchScore,
  });

  final String id;
  final String name;
  final String category;
  final String level;
  final List<String> tags;
  final String teamSize;
  final String signupTime;
  final String contestTime;
  final String format;
  final String organizer;
  final String? officialUrl;
  final String reason;
  final List<String> preparationTips;
  final List<String> limitations;

  /// 0.0-1.0 的归一化匹配度。
  final double matchScore;
}
