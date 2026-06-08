import 'professor.dart';
import 'recommendation.dart';

/// 本地收藏的导师快照。
class FavoriteItem {
  const FavoriteItem({
    required this.professorId,
    required this.name,
    required this.university,
    required this.college,
    required this.title,
    required this.researchFields,
    required this.favoritedAt,
    this.homepageUrl,
  });

  final String professorId;
  final String name;
  final String university;
  final String college;
  final String title;
  final List<String> researchFields;
  final String? homepageUrl;
  final DateTime favoritedAt;

  factory FavoriteItem.fromRecommendation(
    Recommendation recommendation, {
    DateTime? favoritedAt,
  }) {
    return FavoriteItem(
      professorId: recommendation.professorId,
      name: recommendation.name,
      university: recommendation.university,
      college: recommendation.college,
      title: recommendation.title,
      researchFields: recommendation.researchFields,
      homepageUrl: recommendation.homepageUrl,
      favoritedAt: favoritedAt ?? DateTime.now(),
    );
  }

  factory FavoriteItem.fromProfessor(
    Professor professor, {
    DateTime? favoritedAt,
  }) {
    return FavoriteItem(
      professorId: professor.id,
      name: professor.name,
      university: professor.university,
      college: professor.college,
      title: professor.title,
      researchFields: professor.researchFields,
      homepageUrl: professor.homepageUrl,
      favoritedAt: favoritedAt ?? DateTime.now(),
    );
  }
}
