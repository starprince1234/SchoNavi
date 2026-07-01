import '../../domain/entities/comparison_report.dart';
import 'api_envelope.dart';
import 'professor_dto.dart';

class ComparisonRowDto {
  const ComparisonRowDto({required this.dimension, required this.cells});

  final String dimension;
  final Map<String, String> cells;

  factory ComparisonRowDto.fromJson(Map<String, dynamic> json) {
    final rawCells = asJsonObject(json['cells']);
    return ComparisonRowDto(
      dimension: json['dimension'] as String,
      cells: rawCells.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'dimension': dimension,
    'cells': cells,
  };

  ComparisonRow toEntity() => ComparisonRow(dimension: dimension, cells: cells);
}

class ComparisonReportDto {
  const ComparisonReportDto({
    required this.professorIds,
    required this.professors,
    required this.rows,
    required this.summary,
    required this.suggestion,
  });

  final List<String> professorIds;
  final List<ProfessorDto> professors;
  final List<ComparisonRowDto> rows;
  final String summary;
  final String suggestion;

  factory ComparisonReportDto.fromJson(Map<String, dynamic> json) {
    return ComparisonReportDto(
      professorIds: stringList(json['professor_ids']),
      professors: (json['professors'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => ProfessorDto.fromJson(asJsonObject(item)))
          .toList(growable: false),
      rows: (json['rows'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => ComparisonRowDto.fromJson(asJsonObject(item)))
          .toList(growable: false),
      summary: json['summary'] as String,
      suggestion: json['suggestion'] as String,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'professor_ids': professorIds,
    'professors': professors.map((item) => item.toJson()).toList(),
    'rows': rows.map((item) => item.toJson()).toList(),
    'summary': summary,
    'suggestion': suggestion,
  };

  ComparisonReport toEntity() => ComparisonReport(
    professorIds: professorIds,
    professors: professors.map((item) => item.toEntity()).toList(),
    rows: rows.map((item) => item.toEntity()).toList(),
    summary: summary,
    suggestion: suggestion,
  );
}
