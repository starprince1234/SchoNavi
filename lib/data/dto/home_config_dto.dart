import '../../domain/entities/home_config.dart';
import 'api_envelope.dart';
import 'home_prompt_dto.dart';

class HomeConfigDto {
  const HomeConfigDto({
    required this.taglines,
    required this.quickTags,
    required this.prompts,
  });

  final List<String> taglines;
  final List<String> quickTags;
  final List<HomePromptDto> prompts;

  factory HomeConfigDto.fromJson(Map<String, dynamic> json) {
    return HomeConfigDto(
      taglines: stringList(json['taglines']),
      quickTags: stringList(json['quick_tags']),
      prompts: (json['prompts'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => HomePromptDto.fromJson(asJsonObject(item)))
          .toList(growable: false),
    );
  }

  HomeConfig toEntity() => HomeConfig(
    taglines: taglines,
    quickTags: quickTags,
    prompts: prompts.map((item) => item.toEntity()).toList(growable: false),
  );
}
