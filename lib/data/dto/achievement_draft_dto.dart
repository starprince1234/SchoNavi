import '../../domain/repositories/profile_extraction_repository.dart';
import 'api_envelope.dart';
import 'profile_dtos.dart';

class AchievementDraftDto {
  const AchievementDraftDto({
    required this.competitions,
    required this.research,
  });

  final List<CompetitionDto> competitions;
  final List<ResearchItemDto> research;

  factory AchievementDraftDto.fromJson(Map<String, dynamic> json) {
    return AchievementDraftDto(
      competitions:
          (json['competitions'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => CompetitionDto.fromJson(asJsonObject(item)))
              .toList(growable: false),
      research: (json['research'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => ResearchItemDto.fromJson(asJsonObject(item)))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'competitions': competitions.map((item) => item.toJson()).toList(),
    'research': research.map((item) => item.toJson()).toList(),
  };

  AchievementDraft toEntity() => AchievementDraft(
    competitions: competitions.map((item) => item.toEntity()).toList(),
    research: research.map((item) => item.toEntity()).toList(),
  );
}
