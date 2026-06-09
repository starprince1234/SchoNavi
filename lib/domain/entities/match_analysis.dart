/// 导师-学生背景匹配分析（信息性，非录取概率预测）。
class MatchAnalysis {
  const MatchAnalysis({
    required this.professorId,
    required this.summary,
    required this.strengths,
    required this.gaps,
    required this.suggestions,
  });

  final String professorId;
  final String summary;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> suggestions;
}
