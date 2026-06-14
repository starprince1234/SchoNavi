/// 系统对竞赛推荐需求的结构化理解。
class CompetitionQueryUnderstanding {
  const CompetitionQueryUnderstanding({
    required this.directions,
    required this.categories,
    required this.timingPreferences,
    required this.teamPreferences,
    required this.uncertainties,
  });

  final List<String> directions;
  final List<String> categories;
  final List<String> timingPreferences;
  final List<String> teamPreferences;
  final List<String> uncertainties;
}
