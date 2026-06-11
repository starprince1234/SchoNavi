/// 学业成绩：GPA + 量纲 + 排名（均可空）。
class AcademicScore {
  const AcademicScore({this.gpa, this.scale, this.rank});

  final double? gpa; // 例 3.8
  final double? scale; // 量纲：4.0 / 4.3 / 4.5 / 5.0 / 100
  final String? rank; // 自由文本，例 "前 5%"、"3/120"

  bool get isEmpty =>
      gpa == null && scale == null && (rank == null || rank!.isEmpty);

  Map<String, dynamic> toJson() => {
    if (gpa != null) 'gpa': gpa,
    if (scale != null) 'scale': scale,
    if (rank != null && rank!.isNotEmpty) 'rank': rank,
  };

  factory AcademicScore.fromJson(Map<String, dynamic> json) {
    final rank = (json['rank'] as String?)?.trim();
    return AcademicScore(
      gpa: (json['gpa'] as num?)?.toDouble(),
      scale: (json['scale'] as num?)?.toDouble(),
      rank: rank == null || rank.isEmpty ? null : rank,
    );
  }
}
