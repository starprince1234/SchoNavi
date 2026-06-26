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

  /// 推荐后的短快捷操作。字段名沿用历史命名，但 UI 会按短 chip 展示。
  final List<String> followUpQuestions;
}
