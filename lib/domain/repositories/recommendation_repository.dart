import '../../core/result/result.dart';
import '../entities/recommendation_result.dart';
import '../entities/user_profile.dart';

abstract interface class RecommendationRepository {
  /// 根据自然语言 prompt 获取推荐。[profile] 为可选学生档案（背景感知，
  /// 空档案/为 null 时行为与不传一致）。[sessionId] 用于多轮（V0.2+）。
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  });
}
