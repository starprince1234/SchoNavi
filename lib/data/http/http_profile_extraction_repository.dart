import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/repositories/profile_extraction_repository.dart';
import '../dto/achievement_draft_dto.dart';
import '../dto/api_envelope.dart';

class HttpProfileExtractionRepository implements ProfileExtractionRepository {
  const HttpProfileExtractionRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<AchievementDraft>> extract({required String rawText}) {
    return guardApi(
      () => _dio.post<dynamic>(
        '/api/v1/profile/achievements/extract',
        data: <String, dynamic>{'raw_text': rawText},
      ),
      (data) => AchievementDraftDto.fromJson(asJsonObject(data)).toEntity(),
    );
  }
}
