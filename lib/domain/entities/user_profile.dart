/// 学生背景。本地持久化，M3 套磁邮件与 M5 背景匹配共用。
class UserProfile {
  const UserProfile({
    this.name,
    this.degreeStage,
    this.school,
    this.major,
    this.researchInterests = const [],
    this.highlights,
  });

  final String? name;
  final String? degreeStage;
  final String? school;
  final String? major;
  final List<String> researchInterests;
  final String? highlights;

  bool get isEmpty =>
      _blank(name) &&
      _blank(degreeStage) &&
      _blank(school) &&
      _blank(major) &&
      researchInterests.isEmpty &&
      _blank(highlights);

  static bool _blank(String? value) => value == null || value.isEmpty;
}
