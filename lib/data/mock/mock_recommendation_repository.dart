import '../../core/result/result.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../domain/repositories/recommendation_repository.dart';
import 'mock_db.dart';

class MockRecommendationRepository implements RecommendationRepository {
  MockRecommendationRepository(this._db);

  final MockDb _db;

  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    String? sessionId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return Success(_db.recommend(prompt, sessionId: sessionId));
  }
}
