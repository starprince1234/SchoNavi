/// 系统对用户需求的结构化理解。
class QueryUnderstanding {
  const QueryUnderstanding({
    required this.researchInterests,
    required this.preferredLocations,
    required this.preferredUniversities,
    required this.uncertainties,
    this.degreeStage,
  });

  final List<String> researchInterests;
  final List<String> preferredLocations;
  final List<String> preferredUniversities;
  final List<String> uncertainties;
  final String? degreeStage;
}
