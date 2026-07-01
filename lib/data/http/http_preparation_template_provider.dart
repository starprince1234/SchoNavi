import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/preparation_plan.dart'
    show CompetitionTimelineType;
import '../../domain/entities/preparation_template.dart';
import '../../domain/repositories/preparation_template_provider.dart';
import '../dto/api_envelope.dart';
import '../dto/preparation_template_dto.dart';

class HttpPreparationTemplateProvider implements PreparationTemplateProvider {
  const HttpPreparationTemplateProvider(this._dio);

  final Dio _dio;

  @override
  Future<PreparationTemplate> load({
    required CompetitionTimelineType timelineType,
    required bool includeDefense,
    required String category,
    required String competitionId,
  }) async {
    final result = await guardApi(
      () => _dio.get<dynamic>(
        '/api/v1/preparation-templates',
        queryParameters: {
          'timeline_type': timelineType.name,
          'include_defense': includeDefense,
          'category': category,
          'competition_id': competitionId,
        },
      ),
      (data) => PreparationTemplateDto.fromJson(asJsonObject(data)).toEntity(),
    );
    return switch (result) {
      Success(:final data) => data,
      Failure(:final error) => throw error,
    };
  }
}
