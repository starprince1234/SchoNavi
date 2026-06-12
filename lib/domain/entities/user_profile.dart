import 'academic_score.dart';
import 'competition.dart';
import 'research_item.dart';

enum Gender { male, female, other, undisclosed }

/// 学生背景。本地持久化；推荐/套磁/匹配共用。
class UserProfile {
  const UserProfile({
    this.name,
    this.degreeStage,
    this.school,
    this.major,
    this.researchInterests = const [],
    this.highlights,
    this.gender,
    this.targetDegree,
    this.score,
    this.competitions = const [],
    this.research = const [],
  });

  final String? name;
  final String? degreeStage; // 当前阶段
  final String? school;
  final String? major;
  final List<String> researchInterests;
  final String? highlights;

  final Gender? gender;
  final String? targetDegree; // 目标阶段：申请硕士 / 申请博士
  final AcademicScore? score;
  final List<Competition> competitions;
  final List<ResearchItem> research;

  bool get isEmpty =>
      _blank(name) &&
      _blank(degreeStage) &&
      _blank(school) &&
      _blank(major) &&
      researchInterests.isEmpty &&
      _blank(highlights) &&
      gender == null &&
      _blank(targetDegree) &&
      (score == null || score!.isEmpty) &&
      competitions.isEmpty &&
      research.isEmpty;

  /// 完成度 0.0–1.0：7 项命中率（中心页进度环）。
  double get completion {
    var hit = 0;
    if (!_blank(name)) hit++;
    if (gender != null) hit++;
    if (!_blank(school) && !_blank(major)) hit++;
    if (!_blank(targetDegree)) hit++;
    if (score?.gpa != null) hit++;
    if (researchInterests.isNotEmpty) hit++;
    if (competitions.isNotEmpty || research.isNotEmpty) hit++;
    return hit / 7;
  }

  UserProfile copyWith({
    String? name,
    String? degreeStage,
    String? school,
    String? major,
    List<String>? researchInterests,
    String? highlights,
    Gender? gender,
    String? targetDegree,
    AcademicScore? score,
    List<Competition>? competitions,
    List<ResearchItem>? research,
  }) => UserProfile(
    name: name ?? this.name,
    degreeStage: degreeStage ?? this.degreeStage,
    school: school ?? this.school,
    major: major ?? this.major,
    researchInterests: researchInterests ?? this.researchInterests,
    highlights: highlights ?? this.highlights,
    gender: gender ?? this.gender,
    targetDegree: targetDegree ?? this.targetDegree,
    score: score ?? this.score,
    competitions: competitions ?? this.competitions,
    research: research ?? this.research,
  );

  static bool _blank(String? value) => value == null || value.isEmpty;
}
