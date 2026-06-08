import 'match_level.dart';

/// 推荐卡片实体。
class Recommendation {
  const Recommendation({
    required this.professorId,
    required this.name,
    required this.university,
    required this.college,
    required this.title,
    required this.researchFields,
    required this.matchLevel,
    required this.reason,
    required this.limitations,
    this.homepageUrl,
    this.matchScore,
  });

  final String professorId;
  final String name;
  final String university;
  final String college;
  final String title;
  final List<String> researchFields;
  final MatchLevel matchLevel;
  final String reason;
  final List<String> limitations;
  final String? homepageUrl;
  final double? matchScore;
}
