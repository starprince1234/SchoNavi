import '../entities/recommended_competition.dart';

abstract class CompetitionCatalogRepository {
  const CompetitionCatalogRepository();

  RecommendedCompetition? findById(String id);

  Future<RecommendedCompetition?> fetchById(String id) async => findById(id);

  Future<List<RecommendedCompetition>> list() async => const [];
}
