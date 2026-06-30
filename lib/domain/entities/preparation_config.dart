import 'preparation_plan.dart';

class PreparationConfig {
  const PreparationConfig({
    required this.categoryAliases,
    required this.timelineDefaults,
    required this.priorExperienceOptions,
    required this.domainFamiliarityOptions,
  });

  final Map<String, String> categoryAliases;
  final Map<String, CompetitionTimelineType> timelineDefaults;
  final List<String> priorExperienceOptions;
  final List<String> domainFamiliarityOptions;

  String normalizeCategory(String category) {
    final trimmed = category.trim();
    return categoryAliases[trimmed] ?? trimmed;
  }

  CompetitionTimelineType? defaultTimelineFor(String competitionId) {
    return timelineDefaults[competitionId];
  }
}
