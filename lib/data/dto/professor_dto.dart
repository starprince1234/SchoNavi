import '../../domain/entities/professor.dart';

/// 与后端 JSON（snake_case）对应的传输对象。
class ProfessorDto {
  const ProfessorDto({
    required this.professorId,
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

  final String professorId;
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

  factory ProfessorDto.fromJson(Map<String, dynamic> json) {
    return ProfessorDto(
      professorId: json['professor_id'] as String,
      name: json['name'] as String,
      university: json['university'] as String,
      college: json['college'] as String,
      title: json['title'] as String,
      researchFields:
          (json['research_fields'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e as String)
              .toList(),
      bio: json['bio'] as String?,
      homepageUrl: json['homepage_url'] as String?,
      sourceUrl: json['source_url'] as String?,
      updatedAt: json['updated_at'] as String?,
      dataQualityScore: (json['data_quality_score'] as num?)?.toDouble(),
    );
  }

  /// 仅序列化非空字段，保证与输入 JSON 往返一致。
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'professor_id': professorId,
      'name': name,
      'university': university,
      'college': college,
      'title': title,
      'research_fields': researchFields,
      if (bio != null) 'bio': bio,
      if (homepageUrl != null) 'homepage_url': homepageUrl,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (dataQualityScore != null) 'data_quality_score': dataQualityScore,
    };
  }

  Professor toEntity() {
    return Professor(
      id: professorId,
      name: name,
      university: university,
      college: college,
      title: title,
      researchFields: researchFields,
      bio: bio,
      homepageUrl: homepageUrl,
      sourceUrl: sourceUrl,
      updatedAt: updatedAt,
      dataQualityScore: dataQualityScore,
    );
  }
}
