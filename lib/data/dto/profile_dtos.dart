import '../../domain/entities/academic_score.dart';
import '../../domain/entities/competition.dart';
import '../../domain/entities/research_item.dart';
import '../../domain/entities/user_profile.dart';
import 'api_envelope.dart';

class AcademicScoreDto {
  const AcademicScoreDto({
    this.gpa,
    this.scale,
    this.rankMode,
    this.percent,
    this.rankPosition,
    this.rankTotal,
  });

  final double? gpa;
  final double? scale;
  final RankMode? rankMode;
  final int? percent;
  final int? rankPosition;
  final int? rankTotal;

  factory AcademicScoreDto.fromJson(Map<String, dynamic> json) {
    return AcademicScoreDto(
      gpa: (json['gpa'] as num?)?.toDouble(),
      scale: (json['scale'] as num?)?.toDouble(),
      rankMode: _rankModeFromDtoName(json['rank_mode']),
      percent: (json['percent'] as num?)?.toInt(),
      rankPosition: (json['rank_position'] as num?)?.toInt(),
      rankTotal: (json['rank_total'] as num?)?.toInt(),
    );
  }

  factory AcademicScoreDto.fromEntity(AcademicScore score) {
    return AcademicScoreDto(
      gpa: score.gpa,
      scale: score.scale,
      rankMode: score.rankMode,
      percent: score.percent,
      rankPosition: score.rankPosition,
      rankTotal: score.rankTotal,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (gpa != null) 'gpa': gpa,
    if (scale != null) 'scale': scale,
    if (rankMode != null && rankMode != RankMode.none)
      'rank_mode': rankMode!.name,
    if (percent != null) 'percent': percent,
    if (rankPosition != null) 'rank_position': rankPosition,
    if (rankTotal != null) 'rank_total': rankTotal,
  };

  AcademicScore toEntity() => AcademicScore(
    gpa: gpa,
    scale: scale,
    rankMode: rankMode ?? RankMode.none,
    percent: percent,
    rankPosition: rankPosition,
    rankTotal: rankTotal,
  );
}

RankMode? _rankModeFromDtoName(Object? raw) {
  final name = raw?.toString();
  for (final m in RankMode.values) {
    if (m.name == name) return m;
  }
  return null;
}

class CompetitionDto {
  const CompetitionDto({required this.name, this.level, this.award, this.year});

  final String name;
  final String? level;
  final String? award;
  final String? year;

  factory CompetitionDto.fromJson(Map<String, dynamic> json) {
    return CompetitionDto(
      name: json['name']?.toString().trim() ?? '',
      level: _optionalString(json['level']),
      award: _optionalString(json['award']),
      year: _optionalString(json['year']),
    );
  }

  factory CompetitionDto.fromEntity(Competition competition) {
    return CompetitionDto(
      name: competition.name,
      level: competition.level,
      award: competition.award,
      year: competition.year,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    if (level != null) 'level': level,
    if (award != null) 'award': award,
    if (year != null) 'year': year,
  };

  Competition toEntity() =>
      Competition(name: name, level: level, award: award, year: year);
}

class ResearchItemDto {
  const ResearchItemDto({
    required this.type,
    required this.title,
    this.role,
    this.venueOrStatus,
    this.year,
  });

  final String type;
  final String title;
  final String? role;
  final String? venueOrStatus;
  final String? year;

  factory ResearchItemDto.fromJson(Map<String, dynamic> json) {
    return ResearchItemDto(
      type: json['type']?.toString() ?? 'other',
      title: json['title']?.toString().trim() ?? '',
      role: _optionalString(json['role']),
      venueOrStatus: _optionalString(
        json['venue_or_status'] ?? json['venueOrStatus'],
      ),
      year: _optionalString(json['year']),
    );
  }

  factory ResearchItemDto.fromEntity(ResearchItem item) {
    return ResearchItemDto(
      type: item.type.name,
      title: item.title,
      role: item.role,
      venueOrStatus: item.venueOrStatus,
      year: item.year,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'title': title,
    if (role != null) 'role': role,
    if (venueOrStatus != null) 'venue_or_status': venueOrStatus,
    if (year != null) 'year': year,
  };

  ResearchItem toEntity() => ResearchItem(
    type: researchTypeFromString(type),
    title: title,
    role: role,
    venueOrStatus: venueOrStatus,
    year: year,
  );
}

class UserProfileDto {
  const UserProfileDto({
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
  final String? degreeStage;
  final String? school;
  final String? major;
  final List<String> researchInterests;
  final String? highlights;
  final String? gender;
  final String? targetDegree;
  final AcademicScoreDto? score;
  final List<CompetitionDto> competitions;
  final List<ResearchItemDto> research;

  factory UserProfileDto.fromJson(Map<String, dynamic> json) {
    final scoreJson = json['score'];
    return UserProfileDto(
      name: _optionalString(json['name']),
      degreeStage: _optionalString(json['degree_stage']),
      school: _optionalString(json['school']),
      major: _optionalString(json['major']),
      researchInterests: stringList(json['research_interests']),
      highlights: _optionalString(json['highlights']),
      gender: _optionalString(json['gender']),
      targetDegree: _optionalString(json['target_degree']),
      score: scoreJson is Map
          ? AcademicScoreDto.fromJson(Map<String, dynamic>.from(scoreJson))
          : null,
      competitions:
          (json['competitions'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) =>
                    CompetitionDto.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false),
      research: (json['research'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => ResearchItemDto.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }

  factory UserProfileDto.fromEntity(UserProfile profile) {
    return UserProfileDto(
      name: profile.name,
      degreeStage: profile.degreeStage,
      school: profile.school,
      major: profile.major,
      researchInterests: profile.researchInterests,
      highlights: profile.highlights,
      gender: profile.gender?.name,
      targetDegree: profile.targetDegree,
      score: profile.score == null
          ? null
          : AcademicScoreDto.fromEntity(profile.score!),
      competitions: profile.competitions
          .map(CompetitionDto.fromEntity)
          .toList(growable: false),
      research: profile.research
          .map(ResearchItemDto.fromEntity)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (name != null) 'name': name,
    if (gender != null) 'gender': gender,
    if (degreeStage != null) 'degree_stage': degreeStage,
    if (targetDegree != null) 'target_degree': targetDegree,
    if (school != null) 'school': school,
    if (major != null) 'major': major,
    'research_interests': researchInterests,
    if (highlights != null) 'highlights': highlights,
    if (score != null) 'score': score!.toJson(),
    'competitions': competitions.map((item) => item.toJson()).toList(),
    'research': research.map((item) => item.toJson()).toList(),
  };

  UserProfile toEntity() => UserProfile(
    name: name,
    degreeStage: degreeStage,
    school: school,
    major: major,
    researchInterests: researchInterests,
    highlights: highlights,
    gender: _genderFrom(gender),
    targetDegree: targetDegree,
    score: score?.toEntity(),
    competitions: competitions.map((item) => item.toEntity()).toList(),
    research: research.map((item) => item.toEntity()).toList(),
  );
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

Gender? _genderFrom(String? raw) {
  for (final value in Gender.values) {
    if (value.name == raw) return value;
  }
  return null;
}
