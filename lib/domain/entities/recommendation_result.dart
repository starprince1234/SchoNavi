import 'query_understanding.dart';
import 'recommendation.dart';

/// 推荐接口聚合结果。
class RecommendationResult {
  const RecommendationResult({
    required this.sessionId,
    required this.queryUnderstanding,
    required this.recommendations,
    required this.followUpQuestions,
  });

  final String sessionId;
  final QueryUnderstanding queryUnderstanding;
  final List<Recommendation> recommendations;
  final List<String> followUpQuestions;
}
