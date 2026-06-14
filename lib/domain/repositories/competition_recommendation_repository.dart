import '../../core/result/result.dart';
import '../entities/competition_recommendation_result.dart';
import '../entities/user_profile.dart';

abstract interface class CompetitionRecommendationRepository {
  Future<Result<CompetitionRecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  });
}
