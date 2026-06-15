import '../../domain/entities/match_analysis.dart';
import 'api_envelope.dart';

class MatchDimensionDto {
  const MatchDimensionDto({
    required this.label,
    required this.score,
    required this.comment,
  });

  final String label;
  final int score;
  final String comment;

  factory MatchDimensionDto.fromJson(Map<String, dynamic> json) {
    return MatchDimensionDto(
      label: json['label'] as String,
      score: (json['score'] as num).round().clamp(0, 100).toInt(),
      comment: json['comment'] as String,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'score': score,
    'comment': comment,
  };

  MatchDimension toEntity() =>
      MatchDimension(label: label, score: score, comment: comment);
}

class MatchAnalysisDto {
  const MatchAnalysisDto({
    required this.professorId,
    required this.summary,
    required this.strengths,
    required this.gaps,
    required this.suggestions,
    required this.dimensions,
  });

  final String professorId;
  final String summary;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> suggestions;
  final List<MatchDimensionDto> dimensions;

  factory MatchAnalysisDto.fromJson(Map<String, dynamic> json) {
    return MatchAnalysisDto(
      professorId: json['professor_id'] as String,
      summary: json['summary'] as String,
      strengths: stringList(json['strengths']),
      gaps: stringList(json['gaps']),
      suggestions: stringList(json['suggestions']),
      dimensions: (json['dimensions'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => MatchDimensionDto.fromJson(asJsonObject(item)))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'professor_id': professorId,
    'summary': summary,
    'strengths': strengths,
    'gaps': gaps,
    'suggestions': suggestions,
    'dimensions': dimensions.map((item) => item.toJson()).toList(),
  };

  MatchAnalysis toEntity() => MatchAnalysis(
    professorId: professorId,
    summary: summary,
    strengths: strengths,
    gaps: gaps,
    suggestions: suggestions,
    dimensions: dimensions.map((item) => item.toEntity()).toList(),
  );
}

