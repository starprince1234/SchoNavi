import '../../../domain/entities/recommendation.dart';
import '../../../shared/widgets/recommendation_card_data.dart';

/// Recommendation -> RecommendationCardData。
extension RecommendationCardMapper on Recommendation {
  RecommendationCardData toCardData() => RecommendationCardData(
        id: professorId,
        title: name,
        subtitle: '$title / $university / $college',
        tags: researchFields.take(2).toList(growable: false),
        matchScore: matchScore ?? 0,
        reason: reason,
        openUrl: homepageUrl,
        kind: RecommendationKind.mentor,
      );
}
