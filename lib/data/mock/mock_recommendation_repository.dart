import '../../core/result/result.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/recommendation_repository.dart';
import 'mock_db.dart';

class MockRecommendationRepository implements RecommendationRepository {
  MockRecommendationRepository(this._db);

  final MockDb _db;

  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile, // 忽略：mock 为确定性演示数据
    String? sessionId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return Success(_db.recommend(prompt, sessionId: sessionId));
  }
}
