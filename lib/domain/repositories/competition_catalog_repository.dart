import '../entities/recommended_competition.dart';

abstract interface class CompetitionCatalogRepository {
  RecommendedCompetition? findById(String id);
}
