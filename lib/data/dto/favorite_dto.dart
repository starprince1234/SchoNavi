import '../../domain/entities/favorite_item.dart';
import 'api_envelope.dart';

class FavoriteItemDto {
  const FavoriteItemDto({
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
  final DateTime favoritedAt;
  final String? homepageUrl;

  factory FavoriteItemDto.fromJson(Map<String, dynamic> json) {
    return FavoriteItemDto(
      professorId: json['professor_id'] as String,
      name: json['name'] as String,
      university: json['university'] as String,
      college: json['college'] as String,
      title: json['title'] as String,
      researchFields: stringList(json['research_fields']),
      homepageUrl: json['homepage_url'] as String?,
      favoritedAt: DateTime.parse(json['favorited_at'] as String),
    );
  }

  factory FavoriteItemDto.fromEntity(FavoriteItem item) {
    return FavoriteItemDto(
      professorId: item.professorId,
      name: item.name,
      university: item.university,
      college: item.college,
      title: item.title,
      researchFields: item.researchFields,
      homepageUrl: item.homepageUrl,
      favoritedAt: item.favoritedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'professor_id': professorId,
    'name': name,
    'university': university,
    'college': college,
    'title': title,
    'research_fields': researchFields,
    if (homepageUrl != null) 'homepage_url': homepageUrl,
    'favorited_at': favoritedAt.toIso8601String(),
  };

  FavoriteItem toEntity() => FavoriteItem(
    professorId: professorId,
    name: name,
    university: university,
    college: college,
    title: title,
    researchFields: researchFields,
    homepageUrl: homepageUrl,
    favoritedAt: favoritedAt,
  );
}

class FavoriteStatusDto {
  const FavoriteStatusDto({required this.favorited, this.item});

  final bool favorited;
  final FavoriteItemDto? item;

  factory FavoriteStatusDto.fromJson(Map<String, dynamic> json) {
    final itemJson = json['item'];
    return FavoriteStatusDto(
      favorited: json['favorited'] as bool,
      item: itemJson is Map
          ? FavoriteItemDto.fromJson(Map<String, dynamic>.from(itemJson))
          : null,
    );
  }
}

