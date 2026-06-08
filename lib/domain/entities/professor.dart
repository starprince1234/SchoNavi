/// 导师详情领域实体。可空字段缺失时 UI 显示「暂无信息」。
class Professor {
  const Professor({
    required this.id,
    required this.name,
    required this.university,
    required this.college,
    required this.title,
    required this.researchFields,
    this.bio,
    this.homepageUrl,
    this.sourceUrl,
    this.updatedAt,
    this.dataQualityScore,
  });

  final String id;
  final String name;
  final String university;
  final String college;
  final String title;
  final List<String> researchFields;
  final String? bio;
  final String? homepageUrl;
  final String? sourceUrl;
  final String? updatedAt;
  final double? dataQualityScore;
}
