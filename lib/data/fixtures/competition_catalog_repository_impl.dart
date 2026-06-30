import '../../domain/entities/recommended_competition.dart';
import '../../domain/repositories/competition_catalog_repository.dart';
import 'competition_catalog.dart';

class StaticCompetitionCatalogRepository extends CompetitionCatalogRepository {
  const StaticCompetitionCatalogRepository();

  @override
  RecommendedCompetition? findById(String id) {
    for (final c in competitionCatalog) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<List<RecommendedCompetition>> list() async => competitionCatalog;
}
