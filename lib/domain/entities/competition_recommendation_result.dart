import 'competition_query_understanding.dart';
import 'recommended_competition.dart';

/// 竞赛推荐接口聚合结果。
class CompetitionRecommendationResult {
  const CompetitionRecommendationResult({
    required this.sessionId,
    required this.understanding,
    required this.recommendations,
    required this.followUpQuestions,
  });

  final String sessionId;
  final CompetitionQueryUnderstanding understanding;
  final List<RecommendedCompetition> recommendations;
  final List<String> followUpQuestions;
}
