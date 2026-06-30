import '../../domain/entities/preparation_template.dart';
import 'api_envelope.dart';

class PreparationTemplateDto {
  const PreparationTemplateDto({required this.phases});

  final List<PreparationTemplatePhase> phases;

  factory PreparationTemplateDto.fromJson(Map<String, dynamic> json) {
    final phases = (json['phases'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => PreparationTemplatePhase.fromJson(asJsonObject(item)))
        .toList(growable: false);
    return PreparationTemplateDto(phases: phases);
  }

  PreparationTemplate toEntity() => PreparationTemplate(phases: phases);
}
