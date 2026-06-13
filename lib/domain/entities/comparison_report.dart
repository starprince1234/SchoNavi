import 'professor.dart';

/// 对比表的一行：一个维度跨多位导师的短评。
class ComparisonRow {
  const ComparisonRow({required this.dimension, required this.cells});

  final String dimension;
  final Map<String, String> cells;
}

/// 多导师横向对比报告。professorIds 维持列顺序。
class ComparisonReport {
  const ComparisonReport({
    required this.professorIds,
    required this.professors,
    required this.rows,
    required this.summary,
    required this.suggestion,
  });

  final List<String> professorIds;
  final List<Professor> professors;
  final List<ComparisonRow> rows;
  final String summary;
  final String suggestion;
}
