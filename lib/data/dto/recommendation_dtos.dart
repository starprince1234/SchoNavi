import '../../domain/entities/match_level.dart';
import '../../domain/entities/query_understanding.dart';
import '../../domain/entities/recommendation.dart';
import '../../domain/entities/recommendation_result.dart';

class QueryUnderstandingDto {
  const QueryUnderstandingDto({
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

  factory QueryUnderstandingDto.fromJson(Map<String, dynamic> json) {
    List<String> strList(String key) =>
        (json[key] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e as String)
            .toList();
    return QueryUnderstandingDto(
      researchInterests: strList('research_interests'),
      preferredLocations: strList('preferred_locations'),
      preferredUniversities: strList('preferred_universities'),
      uncertainties: strList('uncertainties'),
      degreeStage: json['degree_stage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'research_interests': researchInterests,
    'preferred_locations': preferredLocations,
    'preferred_universities': preferredUniversities,
    'degree_stage': degreeStage,
    'uncertainties': uncertainties,
  };

  QueryUnderstanding toEntity() => QueryUnderstanding(
    researchInterests: researchInterests,
    preferredLocations: preferredLocations,
    preferredUniversities: preferredUniversities,
    uncertainties: uncertainties,
    degreeStage: degreeStage,
  );
}

class RecommendationDto {
  const RecommendationDto({
    required this.professorId,
    required this.name,
    required this.university,
    required this.college,
    required this.title,
    required this.researchFields,
    required this.matchLevel,
    required this.reason,
    required this.limitations,
    this.homepageUrl,
    this.matchScore,
  });

  final String professorId;
  final String name;
  final String university;
  final String college;
  final String title;
  final List<String> researchFields;
  final String matchLevel;
  final String reason;
  final List<String> limitations;
  final String? homepageUrl;
  final double? matchScore;

  factory RecommendationDto.fromJson(Map<String, dynamic> json) {
    return RecommendationDto(
      professorId: json['professor_id'] as String,
      name: json['name'] as String,
      university: json['university'] as String,
      college: json['college'] as String,
      title: json['title'] as String,
      researchFields:
          (json['research_fields'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e as String)
              .toList(),
      matchLevel: json['match_level'] as String,
      reason: json['reason'] as String,
      limitations: (json['limitations'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e as String)
          .toList(),
      homepageUrl: json['homepage_url'] as String?,
      matchScore: (json['match_score'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'professor_id': professorId,
    'name': name,
    'university': university,
    'college': college,
    'title': title,
    'research_fields': researchFields,
    'homepage_url': homepageUrl,
    'match_level': matchLevel,
    'match_score': matchScore,
    'reason': reason,
    'limitations': limitations,
  };

  Recommendation toEntity() => Recommendation(
    professorId: professorId,
    name: name,
    university: university,
    college: college,
    title: title,
    researchFields: researchFields,
    matchLevel: MatchLevel.fromLabel(matchLevel),
    reason: reason,
    limitations: limitations,
    homepageUrl: homepageUrl,
    matchScore: matchScore,
  );

  factory RecommendationDto.fromEntity(Recommendation r) =>
      RecommendationDto(
        professorId: r.professorId,
        name: r.name,
        university: r.university,
        college: r.college,
        title: r.title,
        researchFields: r.researchFields,
        matchLevel: r.matchLevel.name,
        reason: r.reason,
        limitations: r.limitations,
        homepageUrl: r.homepageUrl,
        matchScore: r.matchScore,
      );
}

class RecommendationResultDto {
  const RecommendationResultDto({
    required this.sessionId,
    required this.queryUnderstanding,
    required this.recommendations,
    required this.followUpQuestions,
  });

  final String sessionId;
  final QueryUnderstandingDto queryUnderstanding;
  final List<RecommendationDto> recommendations;
  final List<String> followUpQuestions;

  factory RecommendationResultDto.fromJson(Map<String, dynamic> json) {
    return RecommendationResultDto(
      sessionId: json['session_id'] as String,
      queryUnderstanding: QueryUnderstandingDto.fromJson(
        json['query_understanding'] as Map<String, dynamic>,
      ),
      recommendations:
          (json['recommendations'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => RecommendationDto.fromJson(e as Map<String, dynamic>))
              .toList(),
      followUpQuestions:
          (json['follow_up_questions'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e as String)
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'session_id': sessionId,
    'query_understanding': queryUnderstanding.toJson(),
    'recommendations': recommendations.map((e) => e.toJson()).toList(),
    'follow_up_questions': followUpQuestions,
  };

  RecommendationResult toEntity() => RecommendationResult(
    sessionId: sessionId,
    queryUnderstanding: queryUnderstanding.toEntity(),
    recommendations: recommendations.map((e) => e.toEntity()).toList(),
    followUpQuestions: followUpQuestions,
  );
}
