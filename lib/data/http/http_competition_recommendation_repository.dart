import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/competition_recommendation_result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/competition_recommendation_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/competition_recommendation_dtos.dart';
import '../dto/profile_dtos.dart';

class HttpCompetitionRecommendationRepository
    implements CompetitionRecommendationRepository {
  const HttpCompetitionRecommendationRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<CompetitionRecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) {
    return guardApi(
      () => _dio.post<dynamic>(
        '/api/v1/recommendations/competitions',
        data: <String, dynamic>{
          'prompt': prompt,
          'session_id': ?sessionId,
          if (profile != null && !profile.isEmpty)
            'profile': UserProfileDto.fromEntity(profile).toJson(),
        },
      ),
      (data) => CompetitionRecommendationResultDto.fromJson(
        asJsonObject(data),
      ).toEntity(),
    );
  }
}
