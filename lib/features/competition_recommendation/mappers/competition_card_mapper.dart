import '../../../domain/entities/recommended_competition.dart';
import '../../../shared/widgets/recommendation_card_data.dart';

/// RecommendedCompetition -> RecommendationCardData。
extension CompetitionCardMapper on RecommendedCompetition {
  RecommendationCardData toCardData() => RecommendationCardData(
    id: id,
    title: name,
    subtitle: '$category / $level',
    tags: tags.take(2).toList(growable: false),
    matchScore: matchScore,
    reason: reason,
    openUrl: officialUrl,
    kind: RecommendationKind.competition,
  );
}
