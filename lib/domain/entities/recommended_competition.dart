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

  RecommendedCompetition copyWith({
    String? id,
    String? name,
    String? category,
    String? level,
    List<String>? tags,
    String? teamSize,
    String? signupTime,
    String? contestTime,
    String? format,
    String? organizer,
    String? officialUrl,
    String? reason,
    List<String>? preparationTips,
    List<String>? limitations,
    double? matchScore,
  }) =>
      RecommendedCompetition(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        level: level ?? this.level,
        tags: tags ?? this.tags,
        teamSize: teamSize ?? this.teamSize,
        signupTime: signupTime ?? this.signupTime,
        contestTime: contestTime ?? this.contestTime,
        format: format ?? this.format,
        organizer: organizer ?? this.organizer,
        officialUrl: officialUrl ?? this.officialUrl,
        reason: reason ?? this.reason,
        preparationTips: preparationTips ?? this.preparationTips,
        limitations: limitations ?? this.limitations,
        matchScore: matchScore ?? this.matchScore,
      );
}
