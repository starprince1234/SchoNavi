enum RecommendationIntent { mentor, competition }

abstract interface class RecommendationIntentClassifier {
  Future<RecommendationIntent> classify(String prompt);
}
