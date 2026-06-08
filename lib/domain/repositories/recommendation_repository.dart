import '../../core/result/result.dart';
import '../entities/recommendation_result.dart';

abstract interface class RecommendationRepository {
  /// 根据自然语言 prompt 获取推荐。[sessionId] 用于多轮（V0.2+）。
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    String? sessionId,
  });
}
