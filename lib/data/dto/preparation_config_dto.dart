import '../../domain/entities/preparation_config.dart';
import '../../domain/entities/preparation_plan.dart';
import 'api_envelope.dart';

class PreparationConfigDto {
  const PreparationConfigDto({
    required this.categoryAliases,
    required this.timelineDefaults,
    required this.priorExperienceOptions,
    required this.domainFamiliarityOptions,
  });

  final Map<String, String> categoryAliases;
  final Map<String, CompetitionTimelineType> timelineDefaults;
  final List<String> priorExperienceOptions;
  final List<String> domainFamiliarityOptions;

  factory PreparationConfigDto.fromJson(Map<String, dynamic> json) {
    return PreparationConfigDto(
      categoryAliases: _stringMap(json['category_aliases']),
      timelineDefaults: _timelineMap(json['timeline_defaults']),
      priorExperienceOptions: stringList(json['prior_experience_options']),
      domainFamiliarityOptions: stringList(json['domain_familiarity_options']),
    );
  }

  PreparationConfig toEntity() => PreparationConfig(
    categoryAliases: categoryAliases,
    timelineDefaults: timelineDefaults,
    priorExperienceOptions: priorExperienceOptions,
    domainFamiliarityOptions: domainFamiliarityOptions,
  );

  static Map<String, String> _stringMap(Object? value) {
    final raw = value is Map ? value : const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): entry.value.toString(),
    };
  }

  static Map<String, CompetitionTimelineType> _timelineMap(Object? value) {
    final raw = value is Map ? value : const {};
    final out = <String, CompetitionTimelineType>{};
    for (final entry in raw.entries) {
      final parsed = _timeline(entry.value?.toString());
      if (parsed != null) out[entry.key.toString()] = parsed;
    }
    return out;
  }

  static CompetitionTimelineType? _timeline(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in CompetitionTimelineType.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}
